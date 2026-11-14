# Walnutstock: Three Days of Peace, Shells & Music (v1.0)

2D Top-Down Festival Exploration RPG & Interactive Musical Sanctuary built with **Flutter**, **Flame 2D**, **Riverpod**, **Hive CE**, and **SoLoud Spatial Audio (`flutter_soloud`)**.

## Quick Start (Web Preview)

```bash
# Run static analysis & automated test suites
flutter analyze
flutter test

# Build release Web bundle & start COOP/COEP + HTTP 206 streaming preview server
flutter build web --release
node serve.mjs
# Open http://localhost:8080
```

## Regeneration Pipelines (`tool/`)

- `node tool/generate_pixel_art_assets.mjs` — Generates the 256-slot `16x16` orchard tileset, `.tsx` metadata, 9-zone `128x96` `free_orchard_full.tmx`, 28 cultivar/NPC sprite sheets & portraits, and 8 layered 3D-Printed Totems.
- `node tool/generate_audio_and_transcode.mjs` — Synthesizes stereo WAV SFX + 3 Midnight instrumental stems (`track_27_dembow`, `track_28_drupe`, `track_29_omega`) and transcodes all 29 tracks to `.ogg` (Opus) and `.m4a` (AAC).
- `node tool/generate_game_data.mjs` — Builds `assets/data/setlist_26_tracks.json` and `assets/data/npcs_and_quests.json`.
- `node tool/verify_server.mjs` — Integration test verifying `COOP`/`COEP` headers, HTTP `206 Partial Content` byte-range audio streaming, `404` missing-asset handling, and SPA routing.
