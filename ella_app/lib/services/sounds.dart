// Central catalogue of every sound in the app.
//
// One place to see (and edit) every clip + its file. Nothing else in the app
// should hard-code an asset path. Add a clip here, drop the file in
// assets/sounds/, and reference `Sounds.<name>` from the call site.
//
// Paths are relative to `assets/sounds/` (see pubspec assets + README there).
// NOTE: the current asset files all live under `music/` (that's where they were
// dropped); paths below match the files on disk, not the sfx/music split.

/// A single playable sound.
class AudioClip {
  /// Asset path relative to `assets/sounds/` (e.g. `music/tapclick.wav`).
  final String asset;

  /// Whether this clip loops (background music) or plays once (SFX).
  final bool loop;

  /// Per-clip base volume 0..1, multiplied by the master SFX/music volume.
  final double volume;

  const AudioClip(this.asset, {this.loop = false, this.volume = 1.0});

  /// Full asset key including the `sounds/` prefix, for AssetSource.
  String get assetPath => 'sounds/$asset';
}

class Sounds {
  Sounds._();

  // ── Playful Gamey SFX (one-shots) ──────────────────────────────────────────
  static const tap = AudioClip('new-sounds/tap__playful-gamey.wav');
  static const start = AudioClip('new-sounds/start__playful-gamey.wav');
  static const listen = AudioClip('new-sounds/listen__playful-gamey.wav');
  static const send = AudioClip('new-sounds/send__playful-gamey.wav');
  static const turn = AudioClip('new-sounds/turn__playful-gamey.wav');
  static const complete = AudioClip('new-sounds/complete__playful-gamey.wav');
  static const sprout = AudioClip('new-sounds/sprout__playful-gamey.wav');
  static const bloom = AudioClip('new-sounds/bloom__playful-gamey.wav');
  static const level = AudioClip('new-sounds/level__playful-gamey.wav');
  static const newGarden = AudioClip('new-sounds/new-garden__playful-gamey.wav');
  static const topic = AudioClip('new-sounds/topic__playful-gamey.wav');
  static const nudge = AudioClip('new-sounds/nudge__playful-gamey.wav');
  static const error = AudioClip('new-sounds/error__playful-gamey.wav');

  // Deprecated/compatibility aliases
  static const newSprout = sprout;
  static const levelUp = level;

  /// Every SFX clip — used to preload for low-latency playback.
  static const List<AudioClip> allSfx = [
    tap,
    start,
    listen,
    send,
    turn,
    complete,
    sprout,
    bloom,
    level,
    newGarden,
    topic,
    nudge,
    error,
  ];

  // ── Music (looping) ─────────────────────────────────────────────────────────
  /// Garden screen background loop.
  static const gardenMusic = AudioClip(
    'music/garden.wav',
    loop: true,
    volume: 0.6,
  );
}
