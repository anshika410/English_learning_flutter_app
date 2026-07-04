// App audio: one-shot SFX + looping background music.
//
// This is separate from TTS (flutter_tts) which speaks Zoe's lines. When Zoe
// speaks, call [duckForSpeech]/[unduckAfterSpeech] so music lowers and SFX are
// suppressed — the two audio channels never talk over each other.
//
// SFX overlap via a small pool of players (LowLatency mode). Music is a single
// looping player with volume fades. Mute state (music/SFX) persists across
// launches via shared_preferences.

import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sounds.dart';

abstract class AudioInterface {
  Future<void> initialize();

  /// Play a one-shot sound effect. No-op if SFX muted or ducked for speech.
  Future<void> playSfx(AudioClip clip);

  /// Start (or crossfade to) a looping background track. No-op if music muted.
  Future<void> playMusic(AudioClip clip);

  /// Stop the current background track (with a short fade-out).
  Future<void> stopMusic();

  /// Lower music + suppress SFX while Zoe (TTS) is speaking.
  Future<void> duckForSpeech();

  /// Restore music volume + re-enable SFX after Zoe finishes.
  Future<void> unduckAfterSpeech();

  bool get sfxEnabled;
  bool get musicEnabled;
  Future<void> setSfxEnabled(bool value);
  Future<void> setMusicEnabled(bool value);

  Future<void> dispose();
}

/// Fire-and-forget tap click, callable from any widget without a WidgetRef.
/// No-op until [AudioService.initialize] has run, or if SFX are muted.
void playTapClick() => AudioService.maybeInstance?.playSfx(Sounds.tap);

/// Wraps a tap callback so it plays the tap click before running. Returns null
/// when [onTap] is null, so disabled controls stay disabled and stay silent.
/// Apply this at the real gesture widget (GestureDetector/InkWell/onPressed),
/// not at pass-through constructors, to avoid double clicks.
VoidCallback? withTapClick(VoidCallback? onTap) {
  if (onTap == null) return null;
  return () {
    playTapClick();
    onTap();
  };
}

class AudioService implements AudioInterface {
  AudioService({int sfxPoolSize = 4}) : _sfxPoolSize = sfxPoolSize;

  /// The initialized singleton (set by [initialize]). Lets fire-and-forget
  /// helpers like [playTapClick] reach the service without threading a
  /// WidgetRef through every button. There is only ever one AudioService
  /// (created by `audioProvider` and initialized in main()).
  static AudioService? _instance;
  static AudioService? get maybeInstance => _instance;

  static const _kSfxEnabled = 'audio.sfxEnabled';
  static const _kMusicEnabled = 'audio.musicEnabled';

  // How far music dims while TTS speaks (fraction of its normal volume).
  static const double _duckFactor = 0.25;
  static const Duration _fade = Duration(milliseconds: 350);
  static const int _fadeSteps = 14;

  final int _sfxPoolSize;
  final List<AudioPlayer> _sfxPool = [];
  int _sfxCursor = 0;

  final AudioPlayer _musicPlayer = AudioPlayer();
  AudioClip? _currentMusic;

  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  bool _ducked = false;
  bool _ready = false;
  double _musicVolume = 0; // last volume set on _musicPlayer (0..1)
  Timer? _fadeTimer;

  @override
  bool get sfxEnabled => _sfxEnabled;
  @override
  bool get musicEnabled => _musicEnabled;

  @override
  Future<void> initialize() async {
    if (_ready) return;
    _instance = this;

    final prefs = await SharedPreferences.getInstance();
    _sfxEnabled = prefs.getBool(_kSfxEnabled) ?? true;
    _musicEnabled = prefs.getBool(_kMusicEnabled) ?? true;

    // Music: one looping player.
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setPlayerMode(PlayerMode.mediaPlayer);

    // SFX: pool of short-lived, low-latency players reused round-robin so
    // multiple effects can overlap without recreating players each tap.
    for (var i = 0; i < _sfxPoolSize; i++) {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setPlayerMode(PlayerMode.lowLatency);
      _sfxPool.add(p);
    }

    _ready = true;
  }

  @override
  Future<void> playSfx(AudioClip clip) async {
    if (!_ready || !_sfxEnabled || _ducked) return;
    final player = _sfxPool[_sfxCursor];
    _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
    try {
      await player.stop();
      await player.setVolume(clip.volume);
      await player.play(AssetSource(clip.assetPath), volume: clip.volume);
    } catch (_) {
      // Missing asset / platform hiccup — never let a sound crash the UI.
    }
  }

  @override
  Future<void> playMusic(AudioClip clip) async {
    if (!_ready) return;
    // Always (re)start: callers drive this from screen lifecycle (e.g. the
    // garden mount/return), so a fresh start must be reliable even if a prior
    // stop is still settling. An early "already playing" guard here made the
    // loop silent on the second visit.
    _currentMusic = clip;
    if (!_musicEnabled) return;

    _fadeTimer?.cancel();
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      _musicVolume = 0;
      await _musicPlayer.setVolume(0);
      await _musicPlayer.play(AssetSource(clip.assetPath));
      await _fadeMusicTo(_targetMusicVolume());
    } catch (_) {}
  }

  @override
  Future<void> stopMusic() async {
    if (!_ready) return;
    _fadeTimer?.cancel();
    _currentMusic = null;
    try {
      await _fadeMusicTo(0);
      await _musicPlayer.stop();
    } catch (_) {}
  }

  @override
  Future<void> duckForSpeech() async {
    if (_ducked) return;
    _ducked = true;
    if (_ready && _currentMusic != null) {
      await _fadeMusicTo(_targetMusicVolume());
    }
  }

  @override
  Future<void> unduckAfterSpeech() async {
    if (!_ducked) return;
    _ducked = false;
    if (_ready && _currentMusic != null) {
      await _fadeMusicTo(_targetMusicVolume());
    }
  }

  @override
  Future<void> setSfxEnabled(bool value) async {
    _sfxEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSfxEnabled, value);
  }

  @override
  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMusicEnabled, value);
    if (!_ready) return;
    if (value) {
      if (_currentMusic != null) await playMusic(_currentMusic!);
    } else {
      _fadeTimer?.cancel();
      await _musicPlayer.stop();
    }
  }

  @override
  Future<void> dispose() async {
    _fadeTimer?.cancel();
    await _musicPlayer.dispose();
    for (final p in _sfxPool) {
      await p.dispose();
    }
    _sfxPool.clear();
    _ready = false;
    if (identical(_instance, this)) _instance = null;
  }

  // ── internal ────────────────────────────────────────────────────────────────

  double _targetMusicVolume() {
    if (!_musicEnabled || _currentMusic == null) return 0;
    final base = _currentMusic!.volume;
    return _ducked ? base * _duckFactor : base;
  }

  /// Linear volume fade so music never pops in/out abruptly.
  Future<void> _fadeMusicTo(double target) async {
    _fadeTimer?.cancel();
    final start = _musicVolume;
    final clampedTarget = target.clamp(0.0, 1.0);
    final completer = Completer<void>();
    var step = 0;
    _fadeTimer = Timer.periodic(_fade ~/ _fadeSteps, (timer) async {
      step++;
      final t = step / _fadeSteps;
      final v = (start + (clampedTarget - start) * t).clamp(0.0, 1.0);
      _musicVolume = v;
      try {
        await _musicPlayer.setVolume(v);
      } catch (_) {}
      if (step >= _fadeSteps) {
        timer.cancel();
        _musicVolume = clampedTarget;
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }
}
