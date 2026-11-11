# Stemkara

Pure open source music streaming for macOS. No ads, no subscriptions, live synchronized lyrics, karaoke mode, and built-in studio controls.

[![macOS](https://img.shields.io/badge/Platform-macOS%20%7C%20Android-black?logo=apple&logoColor=white)](https://github.com/sshrestha-design/stemkara/releases)
[![Release](https://img.shields.io/badge/Release-v1.0.0-red?logo=github)](https://github.com/sshrestha-design/stemkara/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

<br />

<p align="center">
  <img src=".github/assets/hero.png" width="100%" alt="Stemkara - Your Ultimate Music & Stem Isolation Player" />
</p>

---

## Interface Showcase

<table>
  <tr>
    <td width="50%" valign="top">
      <h3 align="center">Studio Superpowers</h3>
      <p align="center"><i>On-device 4-channel stem separation, live karaoke shortcuts, and curated playlist discovery.</i></p>
      <a href=".github/assets/screenshot_home.png"><img src=".github/assets/screenshot_home.png" width="100%" alt="Home Dashboard & Studio Superpowers" /></a>
    </td>
    <td width="50%" valign="top">
      <h3 align="center">Live Karaoke & Synced Lyrics</h3>
      <p align="center"><i>Real-time word-by-word lyric scrolling, pitch guides, Romanization, and fullscreen visualizer.</i></p>
      <a href=".github/assets/screenshot_lyrics.png"><img src=".github/assets/screenshot_lyrics.png" width="100%" alt="Real-Time Synced Lyrics & Live Karaoke" /></a>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3 align="center">Artist Catalog & Top Songs</h3>
      <p align="center"><i>Verified artist discographies, monthly listener statistics, popular tracks, and instant shuffle.</i></p>
      <a href=".github/assets/screenshot_artist.png"><img src=".github/assets/screenshot_artist.png" width="100%" alt="Artist Catalog & Streaming Discography" /></a>
    </td>
    <td width="50%" valign="top">
      <h3 align="center">Personal Library & Offline Cache</h3>
      <p align="center"><i>Categorized collections for Liked Songs, Recently Played, Offline Stems, and curated Radio Stations.</i></p>
      <a href=".github/assets/screenshot_library.png"><img src=".github/assets/screenshot_library.png" width="100%" alt="Personal Library & Offline Stem Storage" /></a>
    </td>
  </tr>
</table>

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

## Downloads

Download pre-compiled binaries from the [Releases](https://github.com/sshrestha-design/stemkara/releases/latest) section:

- **[Stemkara-macOS.dmg](https://github.com/sshrestha-design/stemkara/releases/download/v1.0.0/Stemkara-macOS.dmg)**: Drag-and-drop installer for macOS.
- **[Stemkara-macOS.zip](https://github.com/sshrestha-design/stemkara/releases/download/v1.0.0/Stemkara-macOS.zip)**: Standalone application archive.

### macOS First Launch
If macOS Gatekeeper flags the app upon opening:
1. Right-click `Stemkara.app` in `/Applications` and select **Open**.
2. Or run the terminal command:
   ```bash
   xattr -cr /Applications/Stemkara.app
   ```

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

## Lineage & Derivative Work Notice

Stemkara is an open source derivative work based on [Musify](https://github.com/gokadzev/Musify) created by [Valeri Gokadze](https://github.com/gokadzev), distributed under the terms of the [GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0).

We gratefully acknowledge Valeri Gokadze and all upstream Musify contributors for establishing the original streaming audio foundation. Stemkara builds upon and diverges from that foundation with:
- Native macOS desktop experience with translucent UI panels, responsive layout, and global media key integration
- On-device 4-channel neural stem isolation (Vocals, Drums, Bass, Instruments) and multi-track mixing console
- Real-time synchronized karaoke lyrics with phonetic Romaji guides and pitch tracking
- Decoupled application identifiers, isolated user storage, and performance optimizations

---

## License

```
Copyright (C) 2026 Stemkara Authors
Copyright (C) 2026 Valeri Gokadze

Stemkara is free software licensed under the GNU General Public License v3.0 (GPL-3.0).
You may run, study, share, and modify this software under the terms of GPL-3.0.
```
