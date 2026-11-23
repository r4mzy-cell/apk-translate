import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translate_id/src/services/translation/translation_engine.dart';
import 'package:translate_id/src/services/voice/voice_engine.dart';
import 'package:translate_id/src/services/ocr/ocr_engine.dart';
import 'package:translate_id/src/services/model/model_manager.dart';
import 'package:translate_id/src/core/di/service_locator.dart';

/// Translation engine provider
final translationEngineProvider = Provider<TranslationEngine>((ref) {
  return getIt<TranslationEngine>();
});

/// Voice engine provider
final voiceEngineProvider = Provider<VoiceEngine>((ref) {
  return getIt<VoiceEngine>();
});

/// OCR engine provider
final ocrEngineProvider = Provider<OcrEngine>((ref) {
  return getIt<OcrEngine>();
});

/// Initialize engines provider - call this on app startup
final enginesInitializedProvider = FutureProvider<void>((ref) async {
  final translationEngine = ref.read(translationEngineProvider);
  final voiceEngine = ref.read(voiceEngineProvider);
  final ocrEngine = ref.read(ocrEngineProvider);
  
  // Each engine is isolated: one failing must not skip model scan of the others
  final results = await Future.wait([
    translationEngine.initialize().catchError((e) => AppLogger.error('TranslationEngine init failed', e)),
    voiceEngine.initialize().catchError((e) => AppLogger.error('VoiceEngine init failed', e)),
    ocrEngine.initialize().catchError((e) => AppLogger.error('OcrEngine init failed', e)),
  ]);
  return results;
});