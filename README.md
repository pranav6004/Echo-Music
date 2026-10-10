# Resona

<div align="center">
  <h1>Resona</h1>
  <p><b>High-performance, privacy-first modern desktop music client with studio DSP, synchronized lyrics, AI playlist studio, and seamless streaming.</b></p>

  <p>
    <a href="https://github.com/pranav6004/resona/releases/latest"><img src="https://img.shields.io/github/v/release/pranav6004/resona?color=blue&style=flat-square" alt="Latest Release"/></a>
    <a href="https://github.com/pranav6004/resona/actions"><img src="https://img.shields.io/github/actions/workflow/status/pranav6004/resona/flutter-desktop.yml?style=flat-square&label=build" alt="CI Status"/></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"/></a>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/built%20with-Flutter-02569B?style=flat-square" alt="Flutter"/></a>
  </p>
</div>

---

## Overview

**Resona** is a standalone, native desktop music application crafted for audiophiles and music lovers on Windows and Linux. Built from the ground up for desktop environments using Flutter and the high-fidelity `libmpv` audio backend, Resona combines an ad-free streaming engine with hardware-grade DSP sound processing, multi-provider synchronized lyrics, LLM-powered playlist curation, and privacy-respecting social integrations.

Zero advertisements. Zero trackers. Zero subscriptions.

---

## Key Features

### 🖥️ Desktop-First Interface
- **Responsive 3-Column Ergonomics**: Adaptive sidebar navigation, responsive content grid (2 to 6 columns), and a persistent bottom player bar.
- **Dynamic Side Panel**: Slide-out panel for live synchronized lyrics and real-time reorderable playback queue without modal takeover.
- **Fluid Layout**: Native dark-mode palette, custom geometric branding, mouse-drag carousel support, and full keyboard navigation.

### 🎛️ Studio-Grade Audio DSP & Hardware Engine
- **10-Band Graphic Equalizer**: Precision sliders covering 31 Hz to 16 kHz ISO frequency bands with real-time interactive Bezier curve visualization.
- **Acoustic Enhancers**: Hardware-accelerated Preamp gain (-10 dB to +10 dB), Low-shelf Bass Boost Enhancer (100 Hz), and Spatial Audio stereo width expander.
- **Acoustic Presets**: Instant switching across Flat, Bass Boost, Rock, Pop, Electronic, Vocal, Acoustic, Jazz, Classical, and custom profiles.
- **WASAPI Exclusive Mode (Windows)**: Direct bit-perfect audio streaming to external DACs bypassing the Windows OS audio engine, sample-rate converters, and system limiters.

### 🎵 High-Performance Streaming & Playback
- **Ad-Free Streaming**: Instant access to millions of tracks, albums, artists, and playlists without interruption.
- **Resilient Engine**: High-speed stream resolver with ranged-byte validation for fast track startup (~200ms).
- **Gapless Transitions**: Continuous track flow with automatic audio normalization.
- **Discovery Hubs**: Dedicated Top Charts (with global and country-specific filtering), New Releases, and Moods & Genres.

### 🎤 Synchronized Lyrics
- **Multi-Source Aggregator**: Aggregates lyrics from LRCLIB, KuGou, Paxsenix, and YouLy+.
- **Real-Time Word Sync**: High-precision synchronized lyric highlighting and smooth scrolling.
- **Multilingual Support**: Romanization and built-in AI translation for lyrics in foreign languages.

### 🤖 AI Music Hub
- **Multi-LLM Integration**: Connect directly to Google Gemini, Anthropic Claude, OpenAI, Groq, Mistral, OpenRouter, or local self-hosted endpoints (Ollama / vLLM / LocalAI).
- **Prompt-to-Playlist Studio**: Generate tailored tracklists from natural language prompts, automatically resolve them to audio streams, and save directly to your library.
- **Connection Diagnostics**: Live latency ping and endpoint validator to test custom API keys and base URLs.

### 🌐 Integrations & Social
- **Discord Rich Presence**: Privacy-first Win32 Named Pipe integration (`\\.\pipe\discord-ipc-0`). Displays active song, artist, album art, elapsed time, and status with **zero** Discord user tokens or account risk.
- **Scrobbling**: Full integration with Last.fm and ListenBrainz.
- **Spotify Importer**: Import public Spotify playlists and tracklists directly into your local SQLite library.
- **Listen Together**: Low-latency WebSocket party rooms for synchronized listening with friends.

### 💾 Offline Storage & Library Management
- **Offline Downloads & Caching**: Save songs locally with an integrated download manager.
- **Blocked Artists Filter**: Block specific artists to exclude them from auto-play, radio, and recommendations.
- **Full JSON Backup & Restore**: One-click database export and import to preserve playlists, favorites, and listening history.

---

## Download & Installation

### Pre-Built Binaries

Pre-compiled standalone packages are available on the [Releases Page](https://github.com/pranav6004/resona/releases):

- **Windows (x64)**: Download `Resona-v1.0.0-windows-x64.zip`, extract to any folder, and run `Resona.exe`.
- **Linux (x64)**: Download `resona-linux-x64.tar.gz`, extract, and execute `./resona`. (Requires `libmpv2` / `libmpv-dev` installed).

---

## Building from Source

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24+ recommended)
- **Windows**: Visual Studio 2022 with *Desktop development with C++* workload.
- **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`, `libmpv-dev`.

### Build Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/pranav6004/resona.git
   cd resona/echo_music_flutter
   ```

2. **Fetch dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run in development mode**:
   ```bash
   # On Windows
   flutter run -d windows

   # On Linux
   flutter run -d linux
   ```

4. **Build release package**:
   ```bash
   # On Windows (outputs to build/windows/x64/runner/Release/)
   flutter build windows --release

   # On Linux (outputs to build/linux/x64/release/bundle/)
   flutter build linux --release
   ```

### Running Tests

```bash
cd echo_music_flutter
flutter test
```

---

## Tech Stack & Architecture

- **UI Framework**: [Flutter](https://flutter.dev) (Material 3 with custom desktop responsiveness)
- **Audio Engine**: [libmpv](https://mpv.io) via `media_kit` / `just_audio_media_kit`
- **Database**: SQLite via `sqflite_common_ffi`
- **Networking**: Dart `http` & `web_socket_channel`
- **IPC / System Interop**: Dart FFI (Win32 Named Pipes `kernel32.dll` for Discord RPC)

---

## Legal & Disclaimer

Resona is an open-source, non-commercial software project developed for personal and educational use.

- Resona does not host, store, or distribute any copyrighted audio, video, or media files.
- All media streams are accessed directly from publicly available third-party endpoints.
- All trademarks, logos, and brand names are property of their respective owners.

---

## License

This project is licensed under the **GNU General Public License v3.0** (GPL-3.0). See [LICENSE](LICENSE) for full details.
