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

  // ── SFX (one-shots) ────────────────────────────────────────────────────────
  /// Button/control tap click. Played across the whole app.
  static const tap = AudioClip('music/tapclick.wav');
  static const newSprout = AudioClip('music/new-sprout.wav');
  static const newGarden = AudioClip('music/new-garden.wav');
  static const levelUp = AudioClip('music/level-up.ogg');

  /// Every SFX clip — used to preload for low-latency playback.
  static const List<AudioClip> allSfx = [tap, newSprout, newGarden, levelUp];

  // ── Music (looping) ─────────────────────────────────────────────────────────
  /// Garden screen background loop.
  static const gardenMusic = AudioClip(
    'music/garden.wav',
    loop: true,
    volume: 0.6,
  );
}
