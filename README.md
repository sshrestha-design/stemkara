# Stemkara

Music streaming player with on-device stem isolation, synchronized karaoke lyrics, and a native macOS desktop interface.

---

## Features

- **4-Stem Audio Isolation**: Isolate or mute vocals, drums, bass, and instruments directly using ONNX models.
- **Stem Mixer Console**: Control per-stem gains and mute/solo channels during active playback.
- **macOS Sequoia Interface**: Frosted translucent sidebar, squircle hero artwork, and high-contrast content surfaces following an 8px spacing system.
- **Library Hub**: Categorized collections for Liked Songs, Recently Played, Offline Stems, and Radio Stations with live search and table views.
- **Suggested Artists**: Dynamic artist recommendations calculated from listening history and favorite genres.
- **Live Lyrics & Karaoke**: Synchronized word-by-word playback with Romanization and translation support.
- **Offline Storage**: Save tracks and stem stems locally for offline listening.
- **Radio Stations**: Curated global live streams categorized by genre.
- **Local Network Sync**: Sync playlists and listening history across local devices securely.
- **No Ads**: Open source audio streaming without tracking or subscriptions.

---

## Screenshots

| Home & Studio Superpowers | Library Hub |
|:---:|:---:|
| <img src=".github/assets/screenshot_home.png" width="100%" alt="Home Screen" /> | <img src=".github/assets/screenshot_library.png" width="100%" alt="Library Hub" /> |

| Artist Catalog & Top Songs | Fullscreen Karaoke & Lyrics |
|:---:|:---:|
| <img src=".github/assets/screenshot_artist.png" width="100%" alt="Artist Page" /> | <img src=".github/assets/screenshot_lyrics.png" width="100%" alt="Now Playing Lyrics" /> |

---

## Supported Platforms

| Platform | Status | Audio Backend |
|---|---|---|
| macOS | Supported (Apple Silicon & Intel) | media_kit / AVFoundation |
| Android | Supported (Android 8.0+) | just_audio / ExoPlayer |
| Linux | Beta | media_kit / MPV |
| Windows | Beta | media_kit |

---

## Building from Source

### Prerequisites

- Flutter SDK (3.24 or later)
- macOS: Xcode 15 or later, CocoaPods
- Android: Android Studio, NDK

### Setup

```bash
git clone https://github.com/sshrestha-design/stemkara.git
cd stemkara
flutter pub get
```

### Build Targets

```bash
# macOS Release
flutter build macos --release

# Android APK
flutter build apk --release
```

The compiled macOS bundle outputs to:
`build/macos/Build/Products/Release/Stemkara.app`

---

## Architecture

- `lib/services/stem_service.dart`: Coordinates on-device stem separation pipelines.
- `lib/services/onnx_stem_service.dart`: ONNX Runtime bindings for Spleeter and Demucs models.
- `lib/services/audio_service.dart`: Core playback engine managing queue, background audio, and media session metadata.
- `lib/screens/library_page.dart`: Collection hub with live metrics and playlist management.
- `lib/screens/user_songs_page.dart`: Desktop collection views for Liked, Recent, and Offline songs.
- `lib/screens/radio_stations_page.dart`: Responsive station directory with instant streaming.
- `lib/widgets/now_playing/stem_mixer_dialog.dart`: Live 4-channel stem mixing console.

---

## License

```
Copyright (C) 2026 Stemkara Authors
Copyright (C) 2026 Valeri Gokadze

Stemkara is free software licensed under the GNU General Public License v3.0 (GPL-3.0).
You may run, study, share, and modify this software under the terms of GPL-3.0.
```
