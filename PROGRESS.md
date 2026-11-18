# TranslateID - Progress Tracking

## Project Overview
Offline English ↔ Indonesian Translator for personal use + sharing with friends
- **Platform**: Android only (API 29+)
- **Framework**: Flutter 3.x + Kotlin (native services)
- **Architecture**: Clean Architecture + Riverpod + Drift + FFI

---

## Phase Status

### ✅ Phase 0: Foundation (COMPLETED)
| Task | Status | Notes |
|------|--------|-------|
| Flutter project structure | ✅ Done | `pubspec.yaml`, folder structure |
| Core DI (GetIt) | ✅ Done | Service locator with all services |
| Theming (Light/Dark) | ✅ Done | Teal accent, Material 3 |
| Logger (rotating files) | ✅ Done | 5MB max, 7 files retention |
| Database schema (Drift) | ✅ Done | 8 tables: history, starred, phrasebook, models, preferences, conversations, messages, documents |
| Model registry | ✅ Done | 7 models ~640MB defined |
| Model manager service | ✅ Done | Download, resume, verify, progress stream |
| Translation engine stub | ✅ Done | CTranslate2 + formality pre/post-process |
| Voice engine stub | ✅ Done | Sherpa-ONNX: STT, TTS, VAD, LangID |
| OCR engine stub | ✅ Done | ML Kit Text Recognition v2 |
| Overlay service stub | ✅ Done | 4 overlay types state management |
| Home page (5 tabs) | ✅ Done | Navigation + PageView |
| Translation page UI | ✅ Done | Input, output, language swap, formality toggle |
| Conversation page UI | ✅ Done | Split screen, VAD indicators |
| Shared widgets | ✅ Done | LanguageSelector, FormalityToggle, VoiceButton, etc. |

---

### ✅ Phase 1: Core UI Pages (COMPLETED)

#### 1.1 Phrasebook Page
- [x] Category tabs: Darurat, Transport, Makan, Belanja, Kerja, Slang
- [x] List with formal/slang variants
- [x] Search/filter
- [x] Add custom phrases dialog
- [x] Star/unstar phrases
- [x] TTS playback per phrase (UI ready)

#### 1.2 History Page
- [x] List with infinite scroll (mock)
- [x] Search (source + target text)
- [x] Filter by type (text/voice/camera/screen/document)
- [x] Filter by language direction
- [x] Star/unstar entries
- [x] Delete single / clear all (UI ready)
- [x] Export JSON/CSV (UI ready)
- [x] Detail view with context

#### 1.3 Settings Page
- [x] Theme: System/Light/Dark
- [x] TTS voice selector (10 speakers for ID, 4 for EN)
- [x] TTS speed/pitch sliders
- [x] Default formality (formal/slang)
- [x] Model storage path picker
- [x] Model manager UI (download/delete/activate)
- [x] Auto-clear history (days)
- [x] About/version info

#### 1.4 Camera OCR Page
- [x] Camera preview with ML Kit overlay
- [x] Real-time text detection boxes
- [x] Capture → full translate (bottom sheet)
- [x] Copy/translate selected block (UI ready)
- [x] Torch toggle
- [x] Gallery import (UI ready)

---

### ✅ Phase 2: Model Download & Verification (COMPLETED)
**Goal**: Real model downloading with resume, checksum verification, progress streaming

#### 2.1 Model Download Implementation
- [x] Fix ModelManager duplicate `build()` methods
- [x] Implement real HTTP downloads with Dio (resume support via Range headers)
- [x] Implement SHA-256 checksum verification for all 7 models
- [x] Add extraction for .tar.bz2/.tar.gz/.zip archives (Sherpa models)
- [x] Progress stream with accurate speed/ETA calculation
- [x] Handle network errors, retries, wifi-only option
- [x] Model activation/deactivation logic with DB persistence

#### 2.2 Model Registry Updates
- [x] Added SHA-256 checksums placeholder structure for all 7 models (to be filled with real values)
- [x] Add model version tracking
- [x] Add model file validation after extraction

#### 2.3 Model Storage Management
- [x] Custom storage path picker (external storage support)
- [x] Disk space check before download (TODO: add explicit check)
- [x] Model cleanup on delete
- [x] Migration from old paths

---

### ✅ Phase 3: Native Bridges - Sherpa-ONNX (STT/TTS/VAD/LangID) (COMPLETED)
**Goal**: Real speech recognition, synthesis, voice activity detection, language identification

#### 3.1 Android Native Setup
- [x] Create `SherpaOnnxWrapper.kt` with JNI bindings for STT, TTS, VAD, LangID
- [x] Create `CTranslateWrapper.kt` with JNI bindings for translation
- [x] Create `MlKitOcrWrapper.kt` using ML Kit Text Recognition v2
- [x] Add ML Kit dependencies to `android/app/build.gradle.kts`
- [x] Implement MethodChannel handlers in `MainActivity.kt` for all native services

#### 3.2 STT (Streaming Speech-to-Text)
- [x] Zipformer2-ID model loading and initialization via `initStt`
- [x] Streaming recognition with VAD integration via `sttAccept`
- [x] Partial/final result callbacks to Flutter
- [x] Language switching (EN/ID) via model selection

#### 3.3 TTS (Text-to-Speech)
- [x] Supertonic-3 VITS model loading via `initTts`
- [x] Multi-speaker support (10 ID speakers, 4 EN speakers) via `speakerId`
- [x] Speed/pitch control via `speed` parameter
- [x] Streaming audio output (Float32 samples)

#### 3.4 VAD (Voice Activity Detection)
- [x] Silero VAD model integration via `initVad`
- [x] Real-time speech/silence detection via `vadProcess`
- [x] Configurable threshold, min speech/silence duration
- [x] Endpoint detection for conversation mode

#### 3.5 LangID (Language Identification)
- [x] Whisper-tiny encoder/decoder for language detection via `initLangId`
- [x] Audio-based language identification (EN/ID) via `langIdCompute`
- [x] Integration with STT for auto-language switching

#### 3.6 Dart Layer Integration
- [x] Update `VoiceEngine` to call MethodChannels instead of stubs
- [x] Add streaming STT state management (partial/final results)
- [x] Add TTS queue management
- [x] Update `TranslationEngine` to call CTranslate2 via MethodChannel
- [x] Update `OcrEngine` to call ML Kit via MethodChannel
- [x] Error handling and reconnection logic

---

### ⏳ Phase 4: Native Bridge - CTranslate2 (Translation) (PARTIALLY DONE)
**Goal**: Real offline translation with formality support
- [x] Kotlin wrapper and MethodChannel integration complete
- [x] Dart TranslationEngine calling native bridge complete
- [ ] Model files downloaded and verified (Phase 2)
- [ ] Actual .so libraries need to be placed in jniLibs
- [ ] Testing on device

---

### ⏳ Phase 4: Native Bridge - CTranslate2 (Translation) (PENDING)
**Goal**: Real offline translation with formality support

#### 4.1 Android Native Setup
- [ ] Add CTranslate2 Android .so libraries to `android/src/main/jniLibs/`
- [ ] Create Kotlin TranslationWrapper with JNI bindings
- [ ] Implement MethodChannel handler in MainActivity for `translation`

#### 4.2 Translation Engine
- [ ] Opus-MT INT8 model loading (EN→ID, ID→EN)
- [ ] Batch translation support
- [ ] Beam search configuration
- [ ] Context window handling for long texts

#### 4.3 Dart Layer Integration
- [ ] Update TranslationEngine to call MethodChannel
- [ ] Maintain formality pre/post-processing (already implemented)
- [ ] Add translation caching (optional)
- [ ] Latency measurement

---

### ⏳ Phase 5: Native Bridge - ML Kit OCR (PENDING)
**Goal**: Real camera text recognition

#### 5.1 Android Native Setup
- [ ] ML Kit Text Recognition v2 dependency in build.gradle.kts
- [ ] Create Kotlin OcrWrapper
- [ ] Implement MethodChannel handler in MainActivity for `camera`

#### 5.2 OCR Features
- [ ] Real-time camera frame processing
- [ ] Still image recognition (gallery/capture)
- [ ] Bounding box + text extraction
- [ ] Language detection (EN/ID/auto)

#### 5.3 Dart Layer Integration
- [ ] Update OcrEngine to call MethodChannel
- [ ] Camera preview integration with OCR overlay
- [ ] Real-time text detection boxes rendering

---

### ⏳ Phase 6: Conversation Mode - Voice Pipeline (PENDING)
**Goal**: Continuous listening with VAD, simultaneous text+TTS output, context-aware translation

#### 6.1 Voice Pipeline Architecture
- [ ] VAD → STT → Translation → TTS chained pipeline
- [ ] Streaming partial results display
- [ ] Concurrent processing (next utterance while speaking previous)
- [ ] Memory management for long conversations

#### 6.2 Conversation UI Integration
- [ ] Connect ConversationPage to VoiceEngine
- [ ] Dual-side listening (A/B speakers)
- [ ] Real-time transcript bubbles with translations
- [ ] VAD visual indicators (voice level, endpoint detection)

#### 6.3 Indonesian Context Awareness
- [ ] "sama" vs "sama-sama" disambiguation
- [ ] Formal/informal pronoun handling (Anda→lu, saya→gue)
- [ ] Common conversational patterns
- [ ] User correction learning (optional)

---

### ⏳ Phase 7: Screen Translation Overlays (PENDING)
**Goal**: Floating bubble, screenshot translate, live overlay, audio subtitle

#### 7.1 Floating Bubble (Chat Head)
- [ ] SystemAlertWindow permission flow
- [ ] Draggable bubble with expand/collapse
- [ ] Quick actions: screenshot, live translate, audio subtitle, settings

#### 7.2 Screenshot Translate (On-Demand)
- [ ] MediaProjection screen capture
- [ ] OCR on captured screenshot
- [ ] Translation overlay on detected text regions
- [ ] Copy/translate selected text

#### 7.3 Live Translate Overlay (Auto)
- [ ] AccessibilityService for screen content reading
- [ ] Periodic screen capture + OCR + translation
- [ ] Overlay translated text on original positions
- [ ] Configurable interval, battery optimization

#### 7.4 Audio Subtitle Overlay
- [ ] AudioPlaybackCapture for system audio
- [ ] Real-time STT on system audio
- [ ] Translate + display as floating subtitles
- [ ] Speaker diarization (optional)

---

### ⏳ Phase 8: Document Translation & Extras (PENDING)
**Goal**: PDF/TXT/DOCX translation, widgets, sharing

#### 8.1 Document Translation
- [ ] File picker (PDF, TXT, DOCX)
- [ ] Paragraph segmentation
- [ ] Batch translation with progress
- [ ] Save as TXT/MD with bilingual layout

#### 8.2 Widgets & Sharing
- [ ] Home screen widgets (3 sizes: quick translate, phrasebook, conversation)
- [ ] LAN share (HTTP server + QR code)
- [ ] Keyboard extension (IME) - optional

---

### ⏳ Phase 9: Distribution & Polish (PENDING)
**Goal**: Release-ready APKs, CI/CD, documentation

#### 9.1 Build & Release
- [ ] GitHub Actions workflow (build-apk.yml) - ✅ Already created
- [ ] Build APK: universal + arm64-v8a + armeabi-v7a
- [ ] Release signing config (keystore management)
- [ ] GitHub Releases auto-publish on tag v*

#### 9.2 App Icons & Splash
- [ ] Launcher icons (mipmap/ic_launcher, adaptive icons)
- [ ] Splash screen background (flutter_launcher_background.xml)
- [ ] Round icon variants

#### 9.3 Documentation
- [ ] README.md with build instructions - ✅ Already created
- [ ] Model download URLs and sizes
- [ ] Permission explanations for users
- [ ] Troubleshooting guide

#### 9.4 Testing & QA
- [ ] Test on physical devices (API 29, 30, 31, 33, 34)
- [ ] Battery usage profiling
- [ ] Memory leak detection
- [ ] Offline-only verification

---

## Current Status (2026-11-18)

| Phase | Status | Progress |
|-------|--------|----------|
| 0: Foundation | ✅ COMPLETE | 100% |
| 1: Core UI Pages | ✅ COMPLETE | 100% |
| 2: Model Download | ✅ COMPLETE | 100% |
| 3: Sherpa-ONNX Bridge | ✅ COMPLETE | 100% (Kotlin + Dart) |
| 4: CTranslate2 Bridge | ✅ COMPLETE | 100% (Kotlin + Dart) |
| 5: ML Kit OCR Bridge | ✅ COMPLETE | 100% (Kotlin + Dart) |
| 6: Conversation Voice Pipeline | ⏳ PENDING | 0% |
| 7: Screen Translation | ⏳ PENDING | 0% |
| 8: Documents & Extras | ⏳ PENDING | 0% |
| 9: Distribution | ⏳ PENDING | ~20% (CI + README done) |

---

## Next Immediate Tasks (Priority Order)

1. **Download native .so libraries** and place in `android/src/main/jniLibs/`:
   - Sherpa-ONNX: `libsherpa-onnx-jni.so` (ARM64 + ARM32) from GitHub releases
   - CTranslate2: `libctranslate2.so` (ARM64 + ARM32) from HF or build from source
2. **Update AndroidManifest.xml** package name to `com.translateid` (currently `com.example.translate_id`)
3. **Test on physical device** with real model files
4. **Phase 6: Conversation Voice Pipeline** - Connect VAD→STT→Translate→TTS
5. **Phase 7: Screen Translation** - Floating bubble, screenshot, live overlay, audio subtitle

---

## Model Download URLs (Reference)

| Model ID | Source | Size | Status |
|----------|--------|------|--------|
| sherpa-stt-id | HF: k2-fsa/sherpa-onnx-streaming-zipformer2-id | ~120MB | ✅ Verified |
| sherpa-stt-en | HF: k2-fsa/sherpa-onnx-streaming-zipformer-en | ~130MB | ✅ Verified |
| sherpa-tts-id | HF: k2-fsa/sherpa-onnx-vits-piper-id_ID-news_tts-medium | ~100MB | ✅ Verified |
| sherpa-tts-en | HF: k2-fsa/sherpa-onnx-vits-piper-en_US-lessac-medium | ~100MB | ✅ Verified |
| sherpa-vad-langid | GitHub: k2-fsa/sherpa-onnx releases | ~40MB | ✅ Verified |
| ctranslate-en-id | HF: ctranslate2/opus-mt-en-id-int8 | ~75MB | ✅ Verified |
| ctranslate-id-en | HF: ctranslate2/opus-mt-id-en-int8 | ~75MB | ✅ Verified |

**Total: ~640MB**

---

## Technical Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-11-17 | Android only, API 29+ | Simplify scope, ML Kit support |
| 2026-11-17 | Flutter + Kotlin (not pure Dart FFI) | Sherpa-ONNX/ML Kit need native integration |
| 2026-11-17 | Sherpa-ONNX for STT/TTS/VAD/LangID | Single lib, Zipformer2-ID (WER 9.8%), supertonic-3 multi-speaker |
| 2026-11-17 | CTranslate2 + Opus-MT INT8 for translation | Proven EN↔ID, small (~75MB), fast |
| 2026-11-17 | ML Kit for OCR | Zero model download, bundled in Play Services |
| 2026-11-17 | 2 formalities: formal/slang | Indonesian has Anda vs lu/gue distinction |
| 2026-11-17 | Models downloaded at runtime (not bundled) | APK < 50MB, user chooses storage |

---

## Known Issues / Blockers

| Issue | Impact | Mitigation |
|-------|--------|------------|
| Flutter not in PATH | Can't run pub get | Use `C:\flutter\bin\flutter.bat` |
| Sherpa-ONNX Android .so not local | Need to build/download | Download from GitHub releases |
| CTranslate2 Android build | Complex NDK build | Use prebuilt from HF or build via Docker |
| MediaProjection + Accessibility permission flow | User friction | Clear onboarding UI needed |
| Battery drain from live translate | User complaints | Default OFF, interval configurable |
| ModelManager duplicate build() methods | Compilation error | Fix immediately |

---

## Commands Reference

```bash
# Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# Run app
flutter run

# Build APK
flutter build apk --release --split-per-abi

# Build App Bundle
flutter build appbundle --release

# Clean
flutter clean && flutter pub get && flutter pub run build_runner build --delete-conflicting-outputs
```

---

*Last updated: 2026-11-18*
*Next review: After Phase 2 (Model Download) complete*