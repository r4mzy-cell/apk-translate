// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ModelInfo _$ModelInfoFromJson(Map<String, dynamic> json) => _ModelInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$ModelTypeEnumMap, json['type']),
      language: json['language'] as String,
      version: json['version'] as String?,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      checksum: json['checksum'] as String?,
      localPath: json['localPath'] as String?,
      isDownloaded: json['isDownloaded'] as bool,
      isActive: json['isActive'] as bool,
      downloadedAt: json['downloadedAt'] == null
          ? null
          : DateTime.parse(json['downloadedAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ModelInfoToJson(_ModelInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$ModelTypeEnumMap[instance.type]!,
      'language': instance.language,
      'version': instance.version,
      'sizeBytes': instance.sizeBytes,
      'checksum': instance.checksum,
      'localPath': instance.localPath,
      'isDownloaded': instance.isDownloaded,
      'isActive': instance.isActive,
      'downloadedAt': instance.downloadedAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$ModelTypeEnumMap = {
  ModelType.stt: 'stt',
  ModelType.tts: 'tts',
  ModelType.translation: 'translation',
  ModelType.vad: 'vad',
  ModelType.langId: 'langid',
};
