# TranslateID

**Offline English ↔ Indonesian Translator** — Built for personal use + sharing with friends.

No internet required. No accounts. No ads. No tracking. Just translate.

---

## Features

### Core (P0)
- **Text Translation** — EN↔ID, auto-detect, swap, copy, share
- **Voice Translation** — Tap mic → STT → Translate → TTS
- **Formality Toggle** — Formal (Anda/bapak/ibu) ↔ Tidak Formal (lu/gue/nggak)
- **History** — 1000 items, search, filter, export JSON/CSV
- **Phrasebook** — 6 categories (Darurat, Transport, Makan, Belanja, Kerja, Slang) with formal/slang variants
- **Model Manager** — WiFi-only download, resume, verify checksum, external storage

### Comfort (P1)
- **Camera OCR** — Real-time overlay, capture → full translate
- **Conversation Mode** — Split screen, VAD auto-switch, tap-to-talk
- **Settings** — Theme, TTS voice (10 speakers ID), speed/pitch, storage path

### Advanced (P2)
- **Screen Translate** — Floating bubble, screenshot translate, live overlay
- **Audio Subtitle** — System audio capture → subtitle overlay
- **Widgets** — Quick translate from home screen
- **LAN Share** — QR code + HTTP for friend install

---

## Architecture

```
Flutter (Dart)                    Kotlin (Native)
┌─────────────────────┐           ┌──────────────────────┐
│ Riverpod State      │ ◄──────►  │ MethodChannels       │
│ Drift Database      │           │  - native (models)   │
│ Service Layer       │           │  - overlay (bubble)  │
│ UI Pages            │           │  - camera (OCR)      │
└─────────────────────┘           │  - audio (capture)   │
                                  │ Services             │
                                  │  - ScreenCapture     │
                                  │  - OverlayService    │
                                  │  - AudioCapture      │
                                  └──────────────────────┘
```

---

## Models (Downloaded at Runtime ~640MB)

| Component | Model | Size |
|-----------|-------|------|
| STT (ID) | sherpa-onnx-streaming-zipformer2-id | ~120MB |
| STT (EN) | sherpa-onnx-streaming-zipformer-en | ~130MB |
| TTS (ID) | sherpa-onnx-supertonic-3-id (10 speakers) | ~100MB |
| TTS (EN) | sherpa-onnx-supertonic-3-en | ~100MB |
| VAD + LangID | silero_vad + whisper-tiny | ~40MB |
| Translate (EN→ID) | CTranslate2 + Opus-MT INT8 | ~75MB |
| Translate (ID→EN) | CTranslate2 + Opus-MT INT8 | ~75MB |

---

## Build Instructions

### Prerequisites
- Flutter 3.19+
- Android SDK API 29+
- Java 17
- Git

### Quick Start
```bash
# Clone
git clone <repo>
cd translate_id

# Install dependencies
flutter pub get

# Generate code (Drift, Riverpod, Freezed)
dart run build_runner build --delete-conflicting-outputs

# Run on device
flutter run
```

### Build APK
```bash
# Release (split per ABI for smaller downloads)
flutter build apk --release --split-per-abi

# Output: build/app/outputs/flutter-apk/
# - app-arm64-v8a-release.apk
# - app-armeabi-v7a-release.apk
# - app-x86_64-release.apk

# Universal (larger, single file)
flutter build apk --release
```

### Build App Bundle (Play Store)
```bash
flutter build appbundle --release
```

### Clean Build
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

---

## Project Structure

```
lib/
├── main.dart
├── src/
│   ├── core/
│   │   ├── di/service_locator.dart
│   │   └── theme/app_theme.dart
│   ├── models/
│   │   └── model_info.dart
│   ├── services/
│   │   ├── database/app_database.dart
│   │   ├── model/model_manager.dart
│   │   ├── translation/translation_engine.dart
│   │   ├── voice/voice_engine.dart
│   │   ├── ocr/ocr_engine.dart
│   │   └── overlay/overlay_service.dart
│   ├── features/
│   │   ├── home/
│   │   ├── translation/
│   │   ├── conversation/
│   │   ├── phrasebook/
│   │   ├── history/
│   │   ├── settings/
│   │   └── camera/
│   └── shared/widgets/
│       ├── language_selector.dart
│       ├── formalities_toggle.dart
│       ├── translation_input.dart
│       ├── translation_output.dart
│       └── voice_button.dart

android/
├── src/main/
│   ├── kotlin/com/translateid/
│   │   ├── MainActivity.kt           # Platform channels
│   │   ├── TranslateIdApplication.kt
│   │   └── services/
│   │       ├── ScreenCaptureService.kt
│   │       ├── OverlayService.kt
│   │       └── AudioCaptureService.kt
│   ├── res/
│   │   ├── layout/overlay_*.xml
│   │   ├── drawable/ic_*.xml
│   │   ├── values/strings.xml, colors.xml, themes.xml
│   │   └── xml/accessibility_service_config.xml
│   └── AndroidManifest.xml
```

---

## Native Integration

The app uses **5 MethodChannels** for native functionality:

| Channel | Purpose |
|---------|---------|
| `com.translateid/native` | Model mgmt, permissions, MediaProjection |
| `com.translateid/overlay` | Floating bubble, translation overlays, audio subtitle |
| `com.translateid/camera` | Camera frames for OCR |
| `com.translateid/audio` | Audio capture for STT |
| `com.translateid/model` | Model download progress |

---

## Model Download URLs

Models are downloaded from:
- **Sherpa-ONNX**: `https://github.com/k2-fsa/sherpa-onnx/releases/download/...`
- **CTranslate2**: `https://huggingface.co/ctranslate2/opus-mt-*-int8/resolve/main/...`

First launch downloads ~640MB to external storage (user selectable).

---

## Distribution

### GitHub Releases (Auto)
- Tag `v1.0.0` → Auto-build + Release
- Universal + per-ABI APKs
- App Bundle (AAB)

### Manual Install (Friends)
1. Download APK from GitHub Releases
2. Enable "Install unknown apps" on Android
3. Install APK
4. First launch → Download models (WiFi)

### LAN Share (From App)
- Settings → "Bagikan ke Teman"
- Creates hotspot + HTTP server
- Shows QR code
- Friend scans → downloads APK

---

## License

Personal use only. Not for commercial distribution.

Third-party licenses:
- Sherpa-ONNX (Apache 2.0)
- CTranslate2 (MIT)
- Opus-MT (MIT)
- ML Kit (Google ToS)
- Flutter (BSD)
- Drift (MIT)

---

## Known Limitations

- Android only (API 29+)
- Requires Google Play Services for ML Kit OCR
- Live translate needs Accessibility permission (user enable)
- Audio capture needs Android 10+
- Models ~640MB (download once)

---

## Roadmap

- [ ] Complete Sherpa-ONNX native bridge
- [ ] Complete CTranslate2 native bridge
- [ ] AccessibilityService for live translate
- [ ] Model download with resume
- [ ] Widgets (3 sizes)
- [ ] Keyboard extension (IME)
- [ ] Document translate (PDF/TXT/DOCX)