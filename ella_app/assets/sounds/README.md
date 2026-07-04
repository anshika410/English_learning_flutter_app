# Sound assets

Drop audio files here, then register them in `lib/services/sounds.dart`.

- `sfx/`   — short one-shot sound effects (taps, chimes, rewards). Prefer `.mp3`/`.wav`, < ~1s.
- `music/` — looping background tracks (home, garden). `.mp3`/`.ogg`.

Asset paths in `Sounds` are relative to `assets/sounds/`
(e.g. `AudioClip('sfx/tap.mp3')` → `assets/sounds/sfx/tap.mp3`).
