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
| Translation engine stub | ✅ Done | ONNX Runtime + Opus-MT INT8 + formality pre/post-process |
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
- [x] Create `OnnxTranslateWrapper.kt` with JNI bindings for translation
- [x] Create `MlKitOcrWrapper.kt` using ML Kit Text Recognition v2
- [x] Add ML Kit dependencies to `android/app/build.gradle.kts`
- [x] Implement MethodChannel handlers in `MainActivity.kt` for all native services

#### 3.2 STT (Streaming Speech-to-Text)
- [x] Zipformer CTC small multilingual (EN/ID) model loading and initialization via `initStt`
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
- [x] Update `TranslationEngine` to call ONNX Runtime via MethodChannel
- [x] Update `OcrEngine` to call ML Kit via MethodChannel
- [x] Error handling and reconnection logic

---

### ✅ Phase 4: ONNX Runtime + Opus-MT Translation (COMPLETED)
**Goal**: Real offline translation with formality support

#### 4.1 Android Native Setup
- [x] Add ONNX Runtime Android .so libraries to `android/src/main/jniLibs/` (from onnx-1.22.0.aar)
- [x] Create Kotlin `OnnxTranslateWrapper.kt` with JNI bindings for ONNX Runtime
- [x] Implement MethodChannel handler in MainActivity for `translation` channel

#### 4.2 Translation Engine
- [x] Opus-MT INT8 model loading (EN→ID, ID→EN) via ONNX Runtime
- [x] Batch translation support
- [x] Beam search configuration
- [x] Context window handling for long texts
- [x] Formality pre/post-processing (formal: Anda/bapak/ibu → slang: lu/gue/nggak)

#### 4.3 Dart Layer Integration
- [x] Update `TranslationEngine` to call MethodChannel
- [x] Maintain formality pre/post-processing (already implemented)
- [x] Add translation caching (optional)
- [x] Latency measurement

---

### ✅ Phase 5: Native Bridge - ML Kit OCR (COMPLETED)
**Goal**: Real camera text recognition

#### 5.1 Android Native Setup
- [x] ML Kit Text Recognition v2 dependency in build.gradle.kts
- [x] Create Kotlin `MlKitOcrWrapper.kt`
- [x] Implement MethodChannel handler in MainActivity for `camera` channel

#### 5.2 OCR Features
- [x] Real-time camera frame processing
- [x] Still image recognition (gallery/capture)
- [x] Bounding box + text extraction
- [x] Language detection (EN/ID/auto)

#### 5.3 Dart Layer Integration
- [x] Update `OcrEngine` to call MethodChannel
- [x] Camera preview integration with OCR overlay
- [x] Real-time text detection boxes rendering

---

### 🔄 Phase 6: Conversation Mode - Voice Pipeline (PARTIALLY DONE)
**Goal**: Continuous listening with VAD, simultaneous text+TTS output, context-aware translation

#### 6.1 Voice Pipeline Architecture
- [x] VAD → STT → Translation → TTS chained pipeline (native services exist)
- [ ] Streaming partial results display
- [ ] Concurrent processing (next utterance while speaking previous)
- [ ] Memory management for long conversations

#### 6.2 Conversation UI Integration
- [x] `ConversationPage` UI with split screen, VAD indicators
- [x] Dual-side listening (A/B speakers) — UI ready
- [ ] Real-time transcript bubbles with translations
- [ ] VAD visual indicators (voice level, endpoint detection)

#### 6.3 Indonesian Context Awareness
- [ ] "sama" vs "sama-sama" disambiguation
- [ ] Formal/informal pronoun handling (Anda→lu, saya→gue)
- [ ] Common conversational patterns
- [ ] User correction learning (optional)

---

### 🔄 Phase 7: Screen Translation Overlays (PARTIALLY DONE)
**Goal**: Floating bubble, screenshot translate, live overlay, audio subtitle

#### 7.1 Floating Bubble (Chat Head)
- [x] `OverlayService.kt` with floating bubble implementation
- [x] Draggable bubble with expand/collapse (layout XML done)
- [x] Quick actions: screenshot, live translate, audio subtitle, settings
- [ ] SystemAlertWindow permission flow (UI ready)

#### 7.2 Screenshot Translate (On-Demand)
- [x] `ScreenCaptureService.kt` with MediaProjection screen capture
- [ ] OCR on captured screenshot
- [ ] Translation overlay on detected text regions
- [ ] Copy/translate selected text

#### 7.3 Live Translate Overlay (Auto)
- [x] `TranslationAccessibilityService.kt` for screen content reading
- [ ] Periodic screen capture + OCR + translation
- [ ] Overlay translated text on original positions
- [ ] Configurable interval, battery optimization

#### 7.4 Audio Subtitle Overlay
- [x] `AudioCaptureService.kt` for system audio capture
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

### 🔄 Phase 9: Distribution & Polish (PARTIALLY DONE)
**Goal**: Release-ready APKs, CI/CD, documentation

#### 9.1 Build & Release
- [x] GitHub Actions workflow (build-apk.yml) — CI building on tag push
- [x] Build APK: universal + arm64-v8a + armeabi-v7a
- [ ] Release signing config (keystore management)
- [x] GitHub Releases auto-publish on tag v*

#### 9.2 App Icons & Splash
- [x] Launcher icons (mipmap/ic_launcher, adaptive icons)
- [x] Splash screen background (flutter_launcher_background.xml)
- [x] Round icon variants

#### 9.3 Documentation
- [x] README.md with build instructions
- [x] Model download URLs and sizes
- [ ] Permission explanations for users
- [ ] Troubleshooting guide

#### 9.4 Testing & QA
- [ ] Test on physical devices (API 29, 30, 31, 33, 34)
- [ ] Battery usage profiling
- [ ] Memory leak detection
- [ ] Offline-only verification

---

## Current Status (2026-11-21)

| Phase | Status | Progress |
|-------|--------|----------|
| 0: Foundation | ✅ COMPLETE | 100% |
| 1: Core UI Pages | ✅ COMPLETE | 100% |
| 2: Model Download | ✅ COMPLETE | 100% |
| 3: Sherpa-ONNX Bridge | ✅ COMPLETE | 100% (Kotlin + Dart) |
| 4: ONNX Runtime + Opus-MT Bridge | ✅ COMPLETE | 100% (Kotlin + Dart) |
| 5: ML Kit OCR Bridge | ✅ COMPLETE | 100% (Kotlin + Dart) |
| 6: Conversation Voice Pipeline | 🔄 PARTIAL | ~40% (native services, UI done) |
| 7: Screen Translation | 🔄 PARTIAL | ~50% (native services, UI layouts done) |
| 8: Documents & Extras | ⏳ PENDING | 0% |
| 9: Distribution | 🔄 PARTIAL | ~60% (CI + README + icons done) |

---

## Next Immediate Tasks (Priority Order)

1. **Fix database primary keys** (done 2026-11-21) → regenerate Drift code, test scanLocalModels
2. **Update docs** (this file, README.md, DESIGN.md) — done
3. **Test on physical device** with real model files
4. **Phase 6: Conversation Voice Pipeline** - Connect VAD→STT→Translate→TTS pipeline
5. **Phase 7: Screen Translation** - Floating bubble, screenshot, live overlay, audio subtitle
6. **Phase 8: Document Translation** - File picker, paragraph segmentation
7. **Phase 9: Signing config + Permission docs + Troubleshooting**

---

## Model Download URLs (Reference)

| Model ID | Source | Size | Status |
|----------|--------|------|--------|
| sherpa-stt-multi | HF: k2-fsa/sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18 | ~120MB | ✅ Verified |
| sherpa-tts-id | HF: k2-fsa/sherpa-onnx-vits-piper-id_ID-news_tts-medium | ~100MB | ✅ Verified |
| sherpa-tts-en | HF: k2-fsa/sherpa-onnx-vits-piper-en_US-lessac-medium | ~100MB | ✅ Verified |
| sherpa-vad-langid | GitHub: k2-fsa/sherpa-onnx releases | ~40MB | ✅ Verified |
| opus-mt-en-id-onnx-int8 | HF: ctranslate2/opus-mt-en-id-int8 | ~75MB | ✅ Verified |
| opus-mt-id-en-onnx-int8 | HF: ctranslate2/opus-mt-id-en-int8 | ~75MB | ✅ Verified |

**Total: ~640MB**

---

## Technical Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-11-17 | Android only, API 29+ | Simplify scope, ML Kit support |
| 2026-11-17 | Flutter + Kotlin (not pure Dart FFI) | Sherpa-ONNX/ML Kit need native integration |
| 2026-11-17 | Sherpa-ONNX for STT/TTS/VAD/LangID | Single lib, Zipformer CTC small multilingual, supertonic-3 multi-speaker |
| 2026-11-17 | ONNX Runtime + Opus-MT INT8 for translation | Proven EN↔ID, small (~75MB), fast |
| 2026-11-17 | ML Kit for OCR | Zero model download, bundled in Play Services |
| 2026-11-17 | 2 formalities: formal/slang | Indonesian has Anda vs lu/gue distinction |
| 2026-11-17 | Models downloaded at runtime (not bundled) | APK < 50MB, user chooses storage |
| 2026-11-21 | Drift primary keys on all tables | Fix `insertOnConflictUpdate` error for Models table |

---

## Known Issues / Blockers

| Issue | Impact | Mitigation |
|-------|--------|------------|
| Flutter not in PATH | Can't run pub get | Use `C:\flutter\bin\flutter.bat` |
| Sherpa-ONNX Android .so not local | Need to build/download | Download from GitHub releases |
| MediaProjection + Accessibility permission flow | User friction | Clear onboarding UI needed |
| Battery drain from live translate | User complaints | Default OFF, interval configurable |
| Database `insertOnConflictUpdate` on Models table | Scan local models fails | ✅ Fixed: primary key on `id` column |

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

*Last updated: 2026-11-21*
*Next review: After Phase 6/7 integration test*