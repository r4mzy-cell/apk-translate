import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_info.freezed.dart';
part 'model_info.g.dart';

@freezed
sealed class ModelInfo with _$ModelInfo {
  const factory ModelInfo({
    required String id,
    required String name,
    required ModelType type,
    required String language,
    String? version,
    required int sizeBytes,
    String? checksum,
    String? localPath,
    required bool isDownloaded,
    required bool isActive,
    DateTime? downloadedAt,
    DateTime? updatedAt,
  }) = _ModelInfo;

  factory ModelInfo.fromJson(Map<String, dynamic> json) => _$ModelInfoFromJson(json);
}

extension ModelInfoExtension on ModelInfo {
  String get sizeFormatted {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  String get typeDisplayName {
    switch (type) {
      case ModelType.stt:
        return 'Speech-to-Text';
      case ModelType.tts:
        return 'Text-to-Speech';
      case ModelType.translation:
        return 'Translation';
      case ModelType.vad:
        return 'Voice Activity Detection';
      case ModelType.langId:
        return 'Language Identification';
    }
  }
}

@JsonEnum()
enum ModelType {
  @JsonValue('stt')
  stt,
  @JsonValue('tts')
  tts,
  @JsonValue('translation')
  translation,
  @JsonValue('vad')
  vad,
  @JsonValue('langid')
  langId,
}

/// Predefined model configurations for the app
class ModelRegistry {
  static List<ModelInfo> get requiredModels => [
    // STT Models (Sherpa-ONNX)
    ModelInfo(
      id: 'sherpa-stt-id',
      name: 'Indonesian STT (Zipformer2)',
      type: ModelType.stt,
      language: 'id',
      sizeBytes: 120 * 1024 * 1024,
      checksum: null,
      isDownloaded: false,
      isActive: false,
    ),
    ModelInfo(
      id: 'sherpa-stt-en',
      name: 'English STT (Zipformer)',
      type: ModelType.stt,
      language: 'en',
      sizeBytes: 130 * 1024 * 1024,
      checksum: null,
      isDownloaded: false,
      isActive: false,
    ),
    // TTS Models (Sherpa-ONNX Supertonic-3)
    ModelInfo(
      id: 'sherpa-tts-id',
      name: 'Indonesian TTS (Supertonic-3, 10 speakers)',
      type: ModelType.tts,
      language: 'id',
      sizeBytes: 100 * 1024 * 1024,
      checksum: null,
      isDownloaded: false,
      isActive: false,
    ),
    ModelInfo(
      id: 'sherpa-tts-en',
      name: 'English TTS (Supertonic-3)',
      type: ModelType.tts,
      language: 'en',
      sizeBytes: 100 * 1024 * 1024,
      checksum: null,
      isDownloaded: false,
      isActive: false,
    ),
    // VAD + LangID (built-in Sherpa)
    ModelInfo(
      id: 'sherpa-vad-langid',
      name: 'VAD + Language ID (Silero + Whisper)',
      type: ModelType.vad,
      language: 'multi',
      sizeBytes: 40 * 1024 * 1024,
      checksum: null,
      isDownloaded: false,
      isActive: false,
    ),
    // Translation Models (CTranslate2 + Opus-MT INT8)
    ModelInfo(
      id: 'ctranslate-en-id',
      name: 'English → Indonesian (Opus-MT INT8)',
      type: ModelType.translation,
      language: 'en-id',
      sizeBytes: 75 * 1024 * 1024,
      checksum: null,
      isDownloaded: false,
      isActive: false,
    ),
    ModelInfo(
      id: 'ctranslate-id-en',
      name: 'Indonesian → English (Opus-MT INT8)',
      type: ModelType.translation,
      language: 'id-en',
      sizeBytes: 75 * 1024 * 1024,
      checksum: null,
      isDownloaded: false,
      isActive: false,
    ),
  ];

  static ModelInfo? findById(String id) {
    try {
      return requiredModels.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<ModelInfo> getByType(ModelType type) {
    return requiredModels.where((m) => m.type == type).toList();
  }

  static int getTotalSizeBytes() {
    return requiredModels.fold(0, (sum, m) => sum + m.sizeBytes);
  }
}