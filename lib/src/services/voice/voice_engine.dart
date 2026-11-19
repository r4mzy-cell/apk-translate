import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:translate_id/src/models/model_info.dart';
import 'package:translate_id/src/services/model/model_manager.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';

/// STT Result
class SttResult {
  final String text;
  final String language;
  final double confidence;
  final bool isFinal;
  final Duration latency;

  const SttResult({
    required this.text,
    required this.language,
    required this.confidence,
    required this.isFinal,
    required this.latency,
  });

  factory SttResult.fromMap(Map<dynamic, dynamic> map) {
    return SttResult(
      text: map['text'] as String? ?? '',
      language: map['language'] as String? ?? 'id',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      isFinal: map['isFinal'] as bool? ?? false,
      latency: Duration.zero,
    );
  }
}

/// TTS Result
class TtsResult {
  final Uint8List audioData;
  final int sampleRate;
  final int channels;
  final Duration latency;

  const TtsResult({
    required this.audioData,
    required this.sampleRate,
    required this.channels,
    required this.latency,
  });

  factory TtsResult.fromMap(Map<dynamic, dynamic> map) {
    final samples = map['samples'] as List<dynamic>? ?? [];
    final audioData = Float32List.fromList(samples.map((e) => (e as num).toDouble()).toList())
        .buffer.asUint8List();
    return TtsResult(
      audioData: audioData,
      sampleRate: map['sampleRate'] as int? ?? 16000,
      channels: 1,
      latency: Duration.zero,
    );
  }
}

/// VAD Result
class VadResult {
  final bool isSpeech;
  final double probability;
  final Duration timestamp;

  const VadResult({
    required this.isSpeech,
    required this.probability,
    required this.timestamp,
  });

  factory VadResult.fromMap(Map<dynamic, dynamic> map) {
    return VadResult(
      isSpeech: map['isSpeech'] as bool? ?? false,
      probability: (map['probability'] as num?)?.toDouble() ?? 0.0,
      timestamp: Duration.zero,
    );
  }
}

/// Language ID Result
class LangIdResult {
  final String language;
  final double confidence;

  const LangIdResult({
    required this.language,
    required this.confidence,
  });

  factory LangIdResult.fromMap(Map<dynamic, dynamic> map) {
    return LangIdResult(
      language: map['language'] as String? ?? 'en',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Voice Engine using Sherpa-ONNX via MethodChannel
class VoiceEngine {
  final ModelManager _modelManager;
  static const _channel = MethodChannel('com.translateid/native');
  static const _sttChannel = EventChannel('com.translateid/native/stt');
  
  bool _initialized = false;
  String _sttId = 'stt_default';
  String _ttsId = 'tts_default';
  bool _vadInitialized = false;
  bool _langIdInitialized = false;

  // Stream controllers for partial STT results
  final _sttPartialController = StreamController<SttResult>.broadcast();
  final _sttFinalController = StreamController<SttResult>.broadcast();
  
  Stream<SttResult> get sttPartialStream => _sttPartialController.stream;
  Stream<SttResult> get sttFinalStream => _sttFinalController.stream;

  VoiceEngine(this._modelManager);

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final status = await _channel.invokeMethod('sherpaStatus');
      _initialized = status['loaded'] == true;
      if (_initialized) {
        AppLogger.info('VoiceEngine initialized via Sherpa-ONNX native bridge');
      } else {
        AppLogger.warning('Sherpa-ONNX library not loaded');
      }
    } catch (e) {
      AppLogger.error('Failed to initialize VoiceEngine', e);
      rethrow;
    }
  }

  // ============ STT (Streaming Speech-to-Text) ============

  /// Create streaming recognizer for a language
  Future<bool> createRecognizer(String language) async {
    if (!_initialized) await initialize();
    
    final model = _getSttModel(language);
    if (model == null || !model.isDownloaded || model.localPath == null) {
      AppLogger.error('STT model not downloaded for $language');
      return false;
    }

    final modelDir = model.localPath!;
    final modelPath = '$modelDir/model.onnx';
    final tokensPath = '$modelDir/tokens.txt';
    
    _sttId = 'stt_$language';
    
    try {
      final result = await _channel.invokeMethod('initStt', {
        'id': _sttId,
        'modelPath': modelPath,
        'tokensPath': tokensPath,
        'numThreads': 2,
        'provider': 'cpu',
        'decodingMethod': 'greedy_search',
        'enableEndpoint': true,
      });
      AppLogger.info('Created STT recognizer for $language: $result');
      return result as bool? ?? false;
    } catch (e) {
      AppLogger.error('Failed to create STT recognizer', e);
      return false;
    }
  }

  /// Feed audio samples to recognizer (streaming)
  Future<SttResult?> acceptWaveform(Float32List samples) async {
    if (!_initialized) return null;
    
    try {
      final samplesDouble = samples.map((e) => e.toDouble()).toList();
      final result = await _channel.invokeMethod('sttAccept', {
        'id': _sttId,
        'samples': samplesDouble,
      });
      
      if (result is Map) {
        final sttResult = SttResult.fromMap(result);
        
        // Emit partial result
        if (sttResult.text.isNotEmpty) {
          _sttPartialController.add(sttResult);
        }
        
        // If endpoint detected, emit final and reset
        if (sttResult.isFinal) {
          _sttFinalController.add(sttResult);
        }
        
        return sttResult;
      }
    } catch (e) {
      AppLogger.error('STT acceptWaveform failed', e);
    }
    return null;
  }

  /// Get current recognition result
  Future<SttResult?> getSttResult() async {
    if (!_initialized) return null;
    try {
      final text = await _channel.invokeMethod('sttGetResult', {'id': _sttId});
      return SttResult(
        text: text as String? ?? '',
        language: 'id',
        confidence: 0.0,
        isFinal: true,
        latency: Duration.zero,
      );
    } catch (e) {
      AppLogger.error('STT getSttResult failed', e);
      return null;
    }
  }

  /// Check if endpoint detected (end of utterance)
  Future<bool> isEndpoint() async {
    if (!_initialized) return false;
    try {
      return await _channel.invokeMethod('sttIsEndpoint', {'id': _sttId}) as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Reset recognizer for new utterance
  Future<void> resetRecognizer() async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod('sttReset', {'id': _sttId});
    } catch (e) {
      AppLogger.error('STT reset failed', e);
    }
  }

  /// Destroy recognizer
  Future<void> destroyRecognizer() async {
    try {
      await _channel.invokeMethod('destroySherpa', {'id': _sttId, 'type': 'stt'});
    } catch (e) {
      AppLogger.error('STT destroy failed', e);
    }
  }

  // ============ TTS (Text-to-Speech) ============

  /// Create TTS engine for a language
  Future<bool> createTts(String language, {String? speakerId, double speed = 1.0}) async {
    if (!_initialized) await initialize();
    
    final model = _getTtsModel(language);
    if (model == null || !model.isDownloaded || model.localPath == null) {
      AppLogger.error('TTS model not downloaded for $language');
      return false;
    }

    final modelDir = model.localPath!;
    final modelPath = '$modelDir/model.onnx';
    final tokensPath = '$modelDir/tokens.txt';
    final dataDir = '$modelDir/espeak-ng-data';
    
    _ttsId = 'tts_$language';
    
    try {
      final result = await _channel.invokeMethod('initTts', {
        'id': _ttsId,
        'modelPath': modelPath,
        'tokensPath': tokensPath,
        'dataDir': dataDir,
        'numThreads': 2,
        'provider': 'cpu',
      });
      AppLogger.info('Created TTS engine for $language: $result');
      return result as bool? ?? false;
    } catch (e) {
      AppLogger.error('Failed to create TTS engine', e);
      return false;
    }
  }

  /// Generate speech from text
  Future<TtsResult?> generateTts(String text) async {
    if (!_initialized) return null;
    
    try {
      final result = await _channel.invokeMethod('ttsGenerate', {
        'id': _ttsId,
        'text': text,
        'speakerId': 0,
        'speed': 1.0,
      });
      
      if (result is Map) {
        return TtsResult.fromMap(result);
      }
    } catch (e) {
      AppLogger.error('TTS generate failed', e);
    }
    return null;
  }

  /// Destroy TTS engine
  Future<void> destroyTts() async {
    try {
      await _channel.invokeMethod('destroySherpa', {'id': _ttsId, 'type': 'tts'});
    } catch (e) {
      AppLogger.error('TTS destroy failed', e);
    }
  }

  // ============ VAD (Voice Activity Detection) ============

  /// Create VAD detector
  Future<bool> createVad() async {
    if (!_initialized) await initialize();
    if (_vadInitialized) return true;
    
    final model = _modelManager.currentModels?.firstWhere(
      (m) => m.id == 'sherpa-vad-langid',
      orElse: () => throw Exception('VAD model not found'),
    );
    
    if (model == null || !model.isDownloaded || model.localPath == null) {
      AppLogger.error('VAD model not downloaded');
      return false;
    }

    final modelDir = model.localPath!;
    final modelPath = '$modelDir/silero_vad.onnx';
    
    try {
      final result = await _channel.invokeMethod('initVad', {
        'modelPath': modelPath,
        'threshold': 0.5,
        'minSilenceDuration': 0.5,
        'minSpeechDuration': 0.25,
      });
      _vadInitialized = result as bool? ?? false;
      AppLogger.info('Created VAD: $_vadInitialized');
      return _vadInitialized;
    } catch (e) {
      AppLogger.error('Failed to create VAD', e);
      return false;
    }
  }

  /// Process audio frame for VAD
  Future<VadResult?> processVad(Float32List samples) async {
    if (!_vadInitialized) return null;
    
    try {
      final samplesDouble = samples.map((e) => e.toDouble()).toList();
      final result = await _channel.invokeMethod('vadProcess', {
        'samples': samplesDouble,
      });
      
      final isSpeech = result as int? ?? 0;
      return VadResult(
        isSpeech: isSpeech > 0,
        probability: isSpeech > 0 ? 0.9 : 0.1,
        timestamp: Duration.zero,
      );
    } catch (e) {
      AppLogger.error('VAD process failed', e);
      return null;
    }
  }

  /// Destroy VAD
  Future<void> destroyVad() async {
    try {
      await _channel.invokeMethod('destroySherpa', {'type': 'vad'});
      _vadInitialized = false;
    } catch (e) {
      AppLogger.error('VAD destroy failed', e);
    }
  }

  // ============ Language Identification ============

  /// Create LangID detector
  Future<bool> createLangId() async {
    if (!_initialized) await initialize();
    if (_langIdInitialized) return true;
    
    final model = _modelManager.currentModels?.firstWhere(
      (m) => m.id == 'sherpa-vad-langid',
      orElse: () => throw Exception('LangID model not found'),
    );
    
    if (model == null || !model.isDownloaded || model.localPath == null) {
      AppLogger.error('LangID model not downloaded');
      return false;
    }

    final modelDir = model.localPath!;
    final encoderPath = '$modelDir/sherpa-onnx-whisper-tiny/encoder.onnx';
    final decoderPath = '$modelDir/sherpa-onnx-whisper-tiny/decoder.onnx';
    final tokensPath = '$modelDir/sherpa-onnx-whisper-tiny/tokens.txt';
    
    try {
      final result = await _channel.invokeMethod('initLangId', {
        'encoderPath': encoderPath,
        'decoderPath': decoderPath,
        'tokensPath': tokensPath,
        'numThreads': 2,
        'provider': 'cpu',
      });
      _langIdInitialized = result as bool? ?? false;
      AppLogger.info('Created LangID: $_langIdInitialized');
      return _langIdInitialized;
    } catch (e) {
      AppLogger.error('Failed to create LangID', e);
      return false;
    }
  }

  /// Identify language from audio
  Future<LangIdResult?> identifyLanguage(Float32List samples) async {
    if (!_langIdInitialized) return null;
    
    try {
      final samplesDouble = samples.map((e) => e.toDouble()).toList();
      final lang = await _channel.invokeMethod('langIdCompute', {
        'samples': samplesDouble,
      });
      
      return LangIdResult(
        language: lang as String? ?? 'en',
        confidence: 0.9,
      );
    } catch (e) {
      AppLogger.error('LangID compute failed', e);
      return null;
    }
  }

  /// Destroy LangID
  Future<void> destroyLangId() async {
    try {
      await _channel.invokeMethod('destroySherpa', {'type': 'langid'});
      _langIdInitialized = false;
    } catch (e) {
      AppLogger.error('LangID destroy failed', e);
    }
  }

  // ============ High-level Combined Operations ============

  /// Full voice translation pipeline: STT -> Translate -> TTS
  Future<VoiceTranslationResult> voiceTranslate({
    required Stream<Float32List> audioStream,
    required String sourceLang,
    required String targetLang,
    required Function(SttResult) onSttPartial,
    required Function(dynamic) onTranslation,
    required Function(TtsResult) onTtsChunk,
  }) async {
    // TODO: Implement full pipeline with TranslationEngine
    return VoiceTranslationResult(
      sttResult: SttResult(text: '', language: sourceLang, confidence: 0, isFinal: true, latency: Duration.zero),
      translationResult: null,
      ttsResult: null,
    );
  }

  // ============ Helpers ============

  ModelInfo? _getSttModel(String language) {
    final models = _modelManager.currentModels;
    if (models == null) return null;
    try {
      return models.firstWhere((m) => m.type == ModelType.stt && m.language == language);
    } catch (_) {
      return null;
    }
  }

  ModelInfo? _getTtsModel(String language) {
    final models = _modelManager.currentModels;
    if (models == null) return null;
    try {
      return models.firstWhere((m) => m.type == ModelType.tts && m.language == language);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _sttPartialController.close();
    _sttFinalController.close();
    destroyRecognizer();
    destroyTts();
    destroyVad();
    destroyLangId();
  }
}

/// Result of full voice translation pipeline
class VoiceTranslationResult {
  final SttResult sttResult;
  final dynamic translationResult;
  final TtsResult? ttsResult;

  const VoiceTranslationResult({
    required this.sttResult,
    this.translationResult,
    this.ttsResult,
  });
}
