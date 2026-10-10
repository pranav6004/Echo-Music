# Resona - Flutter Desktop Engine

This directory contains the cross-platform Flutter application powering **Resona** on Windows, Linux, and macOS.

## Architecture

```
echo_music_flutter/
├── lib/
│   ├── app.dart                   # MaterialApp root & theme configuration
│   ├── main.dart                  # Desktop window initialization & FFI bindings
│   ├── core/                      # Constants, utility functions, responsive helpers
│   ├── data/                      # Local SQLite database (sqflite_common_ffi), settings, download manager
│   ├── innertube/                 # YouTube Music InnerTube HTTP client, protobuf models, renderers
│   ├── lyrics/                    # Multi-engine lyrics aggregator (LRCLIB, KuGou, Paxsenix, YouLy+)
│   ├── playback/                  # Audio handler, media metadata, libmpv player controller, queues
│   ├── services/                  # DSP service, AI service, Discord RPC (Win32 FFI), scrobblers, Party Rooms
│   ├── stream/                    # Resilient stream resolution (VISIONOS with ranged validation)
│   └── ui/                        # Desktop UI components, responsive layout shell, screens, player bars
├── windows/                       # Windows C++ runner, CMakeLists, and Resona application resources
├── linux/                         # Linux GTK/C++ runner and CMake configuration
└── test/                          # Unit and integration test suites
```

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.24+
- **Windows**: Visual Studio 2022 (Desktop C++ workload)
- **Linux**: `libmpv-dev`, `libgtk-3-dev`, `pkg-config`, `ninja-build`

## Development Workflow

### Install Dependencies
```bash
flutter pub get
```

### Run Locally
```bash
# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS
flutter run -d macos
```

### Build Production Releases
```bash
# Windows Release (outputs to build/windows/x64/runner/Release/)
flutter build windows --release

# Linux Release (outputs to build/linux/x64/release/bundle/)
flutter build linux --release
```

### Automated Testing
```bash
flutter test
```

## Key Technologies

- **Audio Playback**: `just_audio` with `just_audio_media_kit` (`libmpv`)
- **DSP Equalizer**: 10-band biquad filter chain, stereotools spatial widener, and lowshelf bass booster
- **Discord RPC**: Native Win32 named pipes (`\\.\pipe\discord-ipc-0`) over Dart FFI
- **Database**: SQLite with reactive stream queries via `sqflite_common_ffi`
- **AI Hub**: OpenAI, Anthropic, Gemini, Groq, Mistral, and local LLM endpoints
