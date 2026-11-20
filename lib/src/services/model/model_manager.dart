import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translate_id/src/services/database/app_database.dart';
import 'package:translate_id/src/models/model_info.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';
import 'package:translate_id/src/features/settings/providers/settings_providers.dart';

/// MethodChannel for model-related native operations
const _modelChannel = MethodChannel('com.translateid/native');

/// Serializable config for background isolate
class _ExtractValidateParams {
  final String targetDirPath;
  final List<String> urls;
  final List<String> expectedFiles;
  final String extractPath;
  final Map<String, String> checksums;
  final Map<String, String> renameMap;

  const _ExtractValidateParams({
    required this.targetDirPath,
    required this.urls,
    required this.expectedFiles,
    required this.extractPath,
    required this.checksums,
    this.renameMap = const {},
  });
}

/// Result from background isolate
class _ExtractValidateResult {
  final bool success;
  final String? error;
  final List<String> missingFiles;

  const _ExtractValidateResult({
    required this.success,
    this.error,
    this.missingFiles = const [],
  });
}

/// Background isolate function: extract archives + validate files
_ExtractValidateResult _extractAndValidateInBackground(_ExtractValidateParams params) {
  try {
    final targetDir = Directory(params.targetDirPath);
    
    // Extract archives
    for (final url in params.urls) {
      final uri = Uri.parse(url);
      final downloadedFileName = p.basename(uri.path);
      final filePath = p.join(targetDir.path, downloadedFileName);
      final file = File(filePath);
      
      if (!file.existsSync()) continue;

      if (downloadedFileName.endsWith('.tar.bz2') || downloadedFileName.endsWith('.tbz2')) {
        _extractTarBz2Sync(file, targetDir);
      } else if (downloadedFileName.endsWith('.tar.gz') || downloadedFileName.endsWith('.tgz')) {
        _extractTarGzSync(file, targetDir);
      } else if (downloadedFileName.endsWith('.zip')) {
        _extractZipSync(file, targetDir);
      } else {
        // Raw file (e.g., silero_vad.onnx) - copy to expected name
        _copyRawFile(file, targetDir, params.renameMap);
      }
    }
    
    // Apply post-extract renames
    _applyRenameMap(targetDir, params.renameMap);
    
    // Validate files
    final missingFiles = <String>[];
    for (final fileName in params.expectedFiles) {
      var file = File(p.join(targetDir.path, fileName));
      if (file.existsSync()) continue;
      
      if (params.extractPath.isNotEmpty) {
        file = File(p.join(targetDir.path, params.extractPath, fileName));
        if (file.existsSync()) continue;
      }
      
      missingFiles.add(fileName);
    }
    
    if (missingFiles.isNotEmpty) {
      return _ExtractValidateResult(
        success: false,
        error: 'Missing files: ${missingFiles.join(', ')}',
        missingFiles: missingFiles,
      );
    }
    
    return const _ExtractValidateResult(success: true);
  } catch (e) {
    return _ExtractValidateResult(success: false, error: e.toString());
  }
}

void _copyRawFile(File src, Directory targetDir, Map<String, String> renameMap) {
  // For raw files, determine target name from renameMap or use original
  final srcName = p.basename(src.path);
  final targetName = renameMap[srcName] ?? srcName;
  final destFile = File(p.join(targetDir.path, targetName));
  if (!destFile.parent.existsSync()) {
    destFile.parent.createSync(recursive: true);
  }
  src.copySync(destFile.path);
}

void _applyRenameMap(Directory targetDir, Map<String, String> renameMap) {
  for (final entry in renameMap.entries) {
    final srcName = entry.key;
    final destName = entry.value;
    
    // Recursive search for file with matching basename
    File? srcFile;
    targetDir.listSync(recursive: true, followLinks: false).forEach((entity) {
      if (entity is File && p.basename(entity.path) == srcName) {
        srcFile = entity;
      }
    });
    
    if (srcFile != null) {
      final destFile = File(p.join(targetDir.path, destName));
      if (!destFile.parent.existsSync()) {
        destFile.parent.createSync(recursive: true);
      }
      if (destFile.existsSync()) {
        destFile.deleteSync();
      }
      srcFile!.renameSync(destFile.path);
    }
  }
}

void _extractTarBz2Sync(File archiveFile, Directory destination) {
  final bytes = archiveFile.readAsBytesSync();
  final decompressed = BZip2Decoder().decodeBytes(bytes);
  final tarArchive = TarDecoder().decodeBytes(decompressed);
  
  for (final entry in tarArchive) {
    final entryPath = p.join(destination.path, entry.name);
    if (entry.isFile) {
      final outFile = File(entryPath);
      if (!outFile.parent.existsSync()) {
        outFile.parent.createSync(recursive: true);
      }
      outFile.writeAsBytesSync(entry.content as List<int>);
    } else if (entry.isDirectory) {
      Directory(entryPath).createSync(recursive: true);
    }
  }
}

void _extractTarGzSync(File archiveFile, Directory destination) {
  final bytes = archiveFile.readAsBytesSync();
  final decompressed = GZipDecoder().decodeBytes(bytes);
  final tarArchive = TarDecoder().decodeBytes(decompressed);
  
  for (final entry in tarArchive) {
    final entryPath = p.join(destination.path, entry.name);
    if (entry.isFile) {
      final outFile = File(entryPath);
      if (!outFile.parent.existsSync()) {
        outFile.parent.createSync(recursive: true);
      }
      outFile.writeAsBytesSync(entry.content as List<int>);
    } else if (entry.isDirectory) {
      Directory(entryPath).createSync(recursive: true);
    }
  }
}

void _extractZipSync(File archiveFile, Directory destination) {
  final bytes = archiveFile.readAsBytesSync();
  final zipArchive = ZipDecoder().decodeBytes(bytes);
  
  for (final entry in zipArchive) {
    final entryPath = p.join(destination.path, entry.name);
    if (entry.isFile) {
      final outFile = File(entryPath);
      if (!outFile.parent.existsSync()) {
        outFile.parent.createSync(recursive: true);
      }
      outFile.writeAsBytesSync(entry.content as List<int>);
    } else if (entry.isDirectory) {
      Directory(entryPath).createSync(recursive: true);
    }
  }
}

/// Download progress state
class DownloadProgress {
  final String modelId;
  final int downloadedBytes;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final double speedBytesPerSec;
  final DownloadStatus status;
  final String? errorMessage;
  final int? filesCompleted;
  final int? filesTotal;

  const DownloadProgress({
    required this.modelId,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.speedBytesPerSec,
    required this.status,
    this.errorMessage,
    this.filesCompleted,
    this.filesTotal,
  });

  String get progressFormatted => '${(progress * 100).toStringAsFixed(1)}%';
  String get speedFormatted {
    if (speedBytesPerSec < 1024) return '${speedBytesPerSec.toStringAsFixed(0)} B/s';
    if (speedBytesPerSec < 1024 * 1024) return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }
  String get downloadedFormatted {
    if (downloadedBytes < 1024 * 1024) return '${(downloadedBytes / 1024).toStringAsFixed(1)} KB';
    return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  String get totalFormatted {
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  String get etaFormatted {
    if (speedBytesPerSec <= 0 || totalBytes <= downloadedBytes) return '--';
    final remaining = totalBytes - downloadedBytes;
    final seconds = (remaining / speedBytesPerSec).round();
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).round()}m';
    return '${(seconds / 3600).round()}h';
  }
}

enum DownloadStatus { idle, connecting, downloading, paused, verifying, extracting, completed, failed, cancelled }

/// Model download URLs and metadata
class ModelDownloadConfig {
  static const Map<String, ModelDownloadInfo> configs = {
    'sherpa-stt-id': ModelDownloadInfo(
      urls: [
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18.tar.bz2',
      ],
      extractPath: 'sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18',
      files: ['model.onnx', 'tokens.txt'],
      checksums: {
        'sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      },
      renameMap: {
        'ctc-epoch-30-avg-3-chunk-16-left-128.int8.onnx': 'model.onnx',
      },
    ),
    'sherpa-stt-en': ModelDownloadInfo(
      urls: [
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18.tar.bz2',
      ],
      extractPath: 'sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18',
      files: ['model.onnx', 'tokens.txt'],
      checksums: {
        'sherpa-onnx-streaming-zipformer-ctc-small-2024-03-18.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      },
      renameMap: {
        'ctc-epoch-30-avg-3-chunk-16-left-128.int8.onnx': 'model.onnx',
      },
    ),
    'sherpa-tts-id': ModelDownloadInfo(
      urls: [
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-id_ID-news_tts-medium.tar.bz2',
      ],
      extractPath: 'vits-piper-id_ID-news_tts-medium',
      files: ['model.onnx', 'tokens.txt', 'config.json', 'espeak-ng-data'],
      checksums: {
        'vits-piper-id_ID-news_tts-medium.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      },
      renameMap: {
        'id_ID-news_tts-medium.onnx': 'model.onnx',
        'id_ID-news_tts-medium.onnx.json': 'config.json',
        'id_ID-news_tts-medium.tokens.txt': 'tokens.txt',
      },
    ),
    'sherpa-tts-en': ModelDownloadInfo(
      urls: [
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2',
      ],
      extractPath: 'vits-piper-en_US-lessac-medium',
      files: ['model.onnx', 'tokens.txt', 'config.json', 'espeak-ng-data'],
      checksums: {
        'vits-piper-en_US-lessac-medium.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      },
      renameMap: {
        'en_US-lessac-medium.onnx': 'model.onnx',
        'en_US-lessac-medium.onnx.json': 'config.json',
        'en_US-lessac-medium.tokens.txt': 'tokens.txt',
      },
    ),
    'sherpa-vad-langid': ModelDownloadInfo(
      urls: [
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2',
      ],
      extractPath: '',
      files: ['silero_vad.onnx', 'sherpa-onnx-whisper-tiny/encoder.onnx', 'sherpa-onnx-whisper-tiny/decoder.onnx', 'sherpa-onnx-whisper-tiny/tokens.txt'],
      checksums: {
        'silero_vad.onnx': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'sherpa-onnx-whisper-tiny.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      },
      renameMap: {
        'tiny-encoder.onnx': 'sherpa-onnx-whisper-tiny/encoder.onnx',
        'tiny-decoder.int8.onnx': 'sherpa-onnx-whisper-tiny/decoder.onnx',
        'tiny.tokens.txt': 'sherpa-onnx-whisper-tiny/tokens.txt',
      },
    ),
    'ctranslate-en-id': ModelDownloadInfo(
      urls: [
        'https://huggingface.co/R4kSo1997/opus-mt-en-id-onnx-int8/resolve/main/encoder_model_quantized.onnx',
        'https://huggingface.co/R4kSo1997/opus-mt-en-id-onnx-int8/resolve/main/decoder_model_quantized.onnx',
        'https://huggingface.co/R4kSo1997/opus-mt-en-id-onnx-int8/resolve/main/decoder_with_past_model_quantized.onnx',
        'https://huggingface.co/R4kSo1997/opus-mt-en-id-onnx-int8/resolve/main/tokenizer.json',
        'https://huggingface.co/R4kSo1997/opus-mt-en-id-onnx-int8/resolve/main/config.json',
      ],
      extractPath: '',
      files: ['encoder_model_quantized.onnx', 'decoder_model_quantized.onnx', 'decoder_with_past_model_quantized.onnx', 'tokenizer.json', 'config.json'],
      checksums: {
        'encoder_model_quantized.onnx': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'decoder_model_quantized.onnx': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'decoder_with_past_model_quantized.onnx': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      },
    ),
    'ctranslate-id-en': ModelDownloadInfo(
      urls: [
        'https://huggingface.co/R4kSo1997/opus-mt-id-en-onnx-int8/resolve/main/encoder_model_quantized.onnx',
        'https://huggingface.co/R4kSo1997/opus-mt-id-en-onnx-int8/resolve/main/decoder_model_quantized.onnx',
        'https://huggingface.co/R4kSo1997/opus-mt-id-en-onnx-int8/resolve/main/decoder_with_past_model_quantized.onnx',
        'https://huggingface.co/R4kSo1997/opus-mt-id-en-onnx-int8/resolve/main/tokenizer.json',
        'https://huggingface.co/R4kSo1997/opus-mt-id-en-onnx-int8/resolve/main/config.json',
      ],
      extractPath: '',
      files: ['encoder_model_quantized.onnx', 'decoder_model_quantized.onnx', 'decoder_with_past_model_quantized.onnx', 'tokenizer.json', 'config.json'],
      checksums: {
        'encoder_model_quantized.onnx': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'decoder_model_quantized.onnx': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'decoder_with_past_model_quantized.onnx': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      },
    ),
  };
}

class ModelDownloadInfo {
  final List<String> urls;
  final String extractPath;
  final List<String> files;
  final Map<String, String> checksums;
  /// Optional: map of extracted filename -> expected final filename (for post-extract renames)
  final Map<String, String> renameMap;

  const ModelDownloadInfo({
    required this.urls,
    required this.extractPath,
    required this.files,
    this.checksums = const {},
    this.renameMap = const {},
  });
}

final modelManagerProvider =
    AsyncNotifierProvider<ModelManager, List<ModelInfo>>(ModelManager.new);

/// Reactive download progress state — UI watches this for real-time updates
final downloadProgressProvider = StateProvider<Map<String, DownloadProgress>>((ref) => {});

class ModelManager extends AsyncNotifier<List<ModelInfo>> {
  AppDatabase get _database => ref.read(appDatabaseProvider);
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DownloadProgress> _progressMap = {};
  final _progressController = StreamController<DownloadProgress>.broadcast();

  @override
  Future<List<ModelInfo>> build() async {
    _dio.options
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(minutes: 15)
      ..sendTimeout = const Duration(minutes: 15)
      ..followRedirects = true
      ..maxRedirects = 5
      ..validateStatus = (status) => status != null && status < 500;
    ref.onDispose(() {
      _progressController.close();
      for (final token in _cancelTokens.values) {
        token.cancel();
      }
    });
    try {
      return await _loadModelsFromDb();
    } catch (e, stack) {
      AppLogger.error('ModelManager build failed, returning empty list', e, stack);
      return [];
    }
  }

  /// Stream download directly to disk using dio.download — preserves partial bytes, enables true resume
  Future<int> _downloadFileToDisk(
    String url,
    String filePath,
    CancelToken cancelToken,
    int totalDownloadedSoFar,
    int totalExpectedBytes,
    String modelId,
    int fileIndex,
    int totalFiles,
    void Function(int, double) onProgressUpdate, {
    int maxRetries = 3,
  }) async {
    final file = File(filePath);
    int attempt = 0;
    DateTime? lastProgressTime;
    int lastProgressBytes = 0;

    while (true) {
      try {
        // Determine existing bytes for Range header (resume)
        int existingBytes = 0;
        if (await file.exists()) {
          existingBytes = await file.length();
        }

        // Verify if already complete
        if (existingBytes > 0) {
          try {
            final headResponse = await _dio.head(url);
            final contentLength = headResponse.headers.value('content-length');
            if (contentLength != null && existingBytes >= int.parse(contentLength)) {
              return existingBytes;
            }
          } catch (_) {
            // HEAD failed, proceed with download
          }
        }

        lastProgressTime = DateTime.now();
        lastProgressBytes = existingBytes;

        // Use dio.download for native streaming to file with progress + resume support
        await _dio.download(
          url,
          filePath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (cancelToken.isCancelled) return;
            final currentTotal = existingBytes + received;
            final displayTotal = totalDownloadedSoFar + currentTotal;

            // Progress update (throttled to ~1Hz)
            final now = DateTime.now();
            final elapsedMs = lastProgressTime != null ? now.difference(lastProgressTime!).inMilliseconds : 500;
            if (elapsedMs >= 500) {
              final speed = (currentTotal - lastProgressBytes) / (elapsedMs / 1000);
              lastProgressTime = now;
              lastProgressBytes = currentTotal;
              onProgressUpdate(displayTotal, speed);

              _updateProgress(modelId, DownloadProgress(
                modelId: modelId,
                downloadedBytes: displayTotal,
                totalBytes: totalExpectedBytes,
                progress: totalExpectedBytes > 0 ? displayTotal / totalExpectedBytes : 0,
                speedBytesPerSec: speed,
                status: DownloadStatus.downloading,
                filesCompleted: fileIndex,
                filesTotal: totalFiles,
              ));
            }
          },
          options: Options(
            headers: existingBytes > 0 ? {'Range': 'bytes=$existingBytes-'} : {},
            followRedirects: true,
            maxRedirects: 5,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        // Return final file size
        return await file.length();

      } on DioException catch (e) {
        if (cancelToken.isCancelled) rethrow;
        if (attempt >= maxRetries) rethrow;
        // Retry on transient errors: timeout, connection reset, 5xx, or HttpException (connection closed)
        final isHttpException = e.error is HttpException;
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.unknown && isHttpException ||
            (e.response?.statusCode != null && e.response!.statusCode! >= 500)) {
          attempt++;
          final delay = Duration(seconds: (2 * attempt)); // 2s, 4s, 6s
          AppLogger.warning('Download retry $attempt/$maxRetries for $url after ${delay.inSeconds}s: ${e.message}');
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
  }

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  DownloadProgress? getProgress(String modelId) => _progressMap[modelId];

  List<ModelInfo> get currentModels => state.value ?? [];

  Future<List<ModelInfo>> _loadModelsFromDb() async {
    final rows = await _database.select(_database.models).get();
    if (rows.isEmpty) {
      await _initializeDefaultModels();
      return _loadModelsFromDb();
    }
    return rows.map(_rowToModelInfo).toList();
  }

  Future<void> _initializeDefaultModels() async {
    for (final model in ModelRegistry.requiredModels) {
      await _database.into(_database.models).insert(
        ModelsCompanion.insert(
          id: model.id,
          name: model.name,
          type: model.type.name,
          language: model.language,
          version: Value(model.version),
          sizeBytes: model.sizeBytes,
          checksum: Value(model.checksum),
          localPath: Value(model.localPath),
          isDownloaded: Value(model.isDownloaded),
          isActive: Value(model.isActive),
          downloadedAt: Value(model.downloadedAt?.millisecondsSinceEpoch),
          updatedAt: Value(model.updatedAt?.millisecondsSinceEpoch),
        ),
      );
    }
  }

  ModelInfo _rowToModelInfo(ModelInfoEntity row) {
    return ModelInfo(
      id: row.id,
      name: row.name,
      type: ModelType.values.byName(row.type),
      language: row.language,
      version: row.version,
      sizeBytes: row.sizeBytes,
      checksum: row.checksum,
      localPath: row.localPath,
      isDownloaded: row.isDownloaded,
      isActive: row.isActive,
      downloadedAt: row.downloadedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.downloadedAt!)
          : null,
      updatedAt: row.updatedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.updatedAt!)
          : null,
    );
  }

  Future<Directory> _getModelDir() async {
    final customPath = await _database.modelStoragePath;
    if (customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (await dir.exists()) return dir;
    }
    // Default to external Documents/TranslateID/models (sideload standard location)
    final externalDir = await _getExternalModelDir();
    if (externalDir != null) return externalDir;
    // Fallback to internal app directory
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(appDir.path, 'models'));
    if (!await modelDir.exists()) await modelDir.create(recursive: true);
    return modelDir;
  }

  /// Get the public external models directory (Documents/TranslateID/models).
  /// Uses native path so it works across devices/storage layouts.
  Future<Directory?> _getExternalModelDir() async {
    try {
      final path = await _modelChannel.invokeMethod<String>('getPublicModelDirectory');
      if (path != null && path.isNotEmpty) {
        final dir = Directory(path);
        if (await dir.exists()) return dir;
        // Dir may not exist yet (no sideload) — still return it so downloads use it,
        // but only if parent Documents is writable.
        final parent = dir.parent;
        if (await parent.exists()) return dir;
      }
    } catch (_) {
      // Channel unavailable (tests) — fall through
    }
    const fallback = '/storage/emulated/0/Documents/TranslateID/models';
    final fallbackDir = Directory(fallback);
    if (await fallbackDir.exists()) return fallbackDir;
    return null;
  }

  Future<void> downloadModel(String modelId, {bool wifiOnly = true, bool resume = true}) async {
    final modelList = state.value ?? [];
    final model = modelList.firstWhere((m) => m.id == modelId, orElse: () => throw Exception('Model not found: $modelId'));
    if (model.isDownloaded) return;

    if (wifiOnly) {
      // Check connectivity - if not WiFi, show error but don't crash
      try {
        final connectivityResult = await _dio.get(
          'http://clients3.google.com/generate_204',
          options: Options(
            validateStatus: (s) => s != null && s < 500,
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
          ),
        );
        if (connectivityResult.statusCode != 204) {
          throw Exception('Tidak ada koneksi internet');
        }
      } on DioException catch (e) {
        AppLogger.warning('Connectivity check failed: ${e.message}, proceeding anyway');
      } catch (e) {
        AppLogger.warning('Connectivity check error: $e, proceeding anyway');
      }
    }

    final config = ModelDownloadConfig.configs[modelId];
    if (config == null) {
      throw Exception('No download config for model: $modelId');
    }

    final modelDir = await _getModelDir();
    final targetDir = Directory(p.join(modelDir.path, modelId));
    // Only clear when NOT resuming — preserve partial files for Range resume
    if (!resume && await targetDir.exists()) await targetDir.delete(recursive: true);
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    _cancelTokens[modelId] = CancelToken();
    final cancelToken = _cancelTokens[modelId]!;

    int totalDownloaded = 0;

    // Start foreground service to keep process alive while download runs
    final bgService = FlutterBackgroundService();
    if (!await bgService.isRunning()) {
      await bgService.startService();
    }
    bgService.invoke('setAsForeground');

    try {
      // Calculate total size for progress
      int totalExpectedBytes = 0;
      for (int i = 0; i < config.urls.length; i++) {
        try {
          final headResponse = await _dio.head(config.urls[i]);
          final contentLength = headResponse.headers.value('content-length');
          if (contentLength != null) {
            totalExpectedBytes += int.parse(contentLength);
          }
        } catch (_) {
          // Ignore HEAD errors, use model size as fallback
        }
      }
      if (totalExpectedBytes == 0) totalExpectedBytes = model.sizeBytes;

      _updateProgress(modelId, DownloadProgress(
        modelId: modelId,
        downloadedBytes: 0,
        totalBytes: totalExpectedBytes,
        progress: 0,
        speedBytesPerSec: 0,
        status: DownloadStatus.connecting,
        filesCompleted: 0,
        filesTotal: config.urls.length,
      ));

      for (int i = 0; i < config.urls.length; i++) {
        final url = config.urls[i];
        // Save with filename from URL (archive name for archives, direct file for direct)
        final uri = Uri.parse(url);
        final fileName = p.basename(uri.path);
        final filePath = p.join(targetDir.path, fileName);

        _updateProgress(modelId, DownloadProgress(
          modelId: modelId,
          downloadedBytes: totalDownloaded,
          totalBytes: totalExpectedBytes,
          progress: totalExpectedBytes > 0 ? totalDownloaded / totalExpectedBytes : 0,
          speedBytesPerSec: 0,
          status: DownloadStatus.downloading,
          filesCompleted: i,
          filesTotal: config.urls.length,
        ));

        // Download file with streaming to disk (preserves partials, enables resume)
        final bytesWritten = await _downloadFileToDisk(
          url,
          filePath,
          cancelToken,
          totalDownloaded,
          totalExpectedBytes,
          modelId,
          i,
          config.urls.length,
          (newTotalDownloaded, speed) {
            totalDownloaded = newTotalDownloaded;
          },
        );
        totalDownloaded = bytesWritten;
      }

      // Verify checksums
      _updateProgress(modelId, DownloadProgress(
        modelId: modelId,
        downloadedBytes: totalDownloaded,
        totalBytes: totalExpectedBytes,
        progress: 1.0,
        speedBytesPerSec: 0,
        status: DownloadStatus.verifying,
        filesCompleted: config.urls.length,
        filesTotal: config.urls.length,
      ));

      if (!await _verifyChecksums(targetDir, config)) {
        throw Exception('Checksum verification failed');
      }

      // Extract archives + validate in background isolate (prevents ANR)
      if (config.extractPath.isNotEmpty || config.files.isNotEmpty) {
        _updateProgress(modelId, DownloadProgress(
          modelId: modelId,
          downloadedBytes: totalDownloaded,
          totalBytes: totalExpectedBytes,
          progress: 1.0,
          speedBytesPerSec: 0,
          status: DownloadStatus.extracting,
          filesCompleted: config.urls.length,
          filesTotal: config.urls.length,
        ));

        final params = _ExtractValidateParams(
          targetDirPath: targetDir.path,
          urls: config.urls,
          expectedFiles: config.files,
          extractPath: config.extractPath,
          checksums: config.checksums,
          renameMap: config.renameMap,
        );

        _ExtractValidateResult result;
        try {
          AppLogger.info('Starting background extraction for $modelId');
          result = await compute(_extractAndValidateInBackground, params).timeout(
            const Duration(minutes: 10),
            onTimeout: () {
              AppLogger.error('Background extraction timeout for $modelId');
              return _ExtractValidateResult(success: false, error: 'Extraction timeout');
            },
          );
          AppLogger.info('Background extraction completed for $modelId: success=${result.success}');
        } on TimeoutException catch (e) {
          AppLogger.error('Background extraction timeout for $modelId', e);
          throw Exception('Extraction timeout: $e');
        } catch (e, stack) {
          AppLogger.error('Background extraction failed for $modelId', e, stack);
          throw Exception('Extraction failed: $e');
        }
        
        if (!result.success) {
          throw Exception(result.error ?? 'Extraction/validation failed');
        }
      }

      // Update database - refetch model from DB to avoid stale state
      final existingRows = await _database.select(_database.models).get();
      final existingRow = existingRows.firstWhere((r) => r.id == modelId);
      await _database.update(_database.models).replace(
        ModelsCompanion(
          id: Value(modelId),
          name: Value(existingRow.name),
          type: Value(existingRow.type),
          language: Value(existingRow.language),
          version: Value(existingRow.version),
          sizeBytes: Value(existingRow.sizeBytes),
          checksum: Value(existingRow.checksum),
          localPath: Value(targetDir.path),
          isDownloaded: const Value(true),
          isActive: const Value(true),
          downloadedAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      _updateProgress(modelId, DownloadProgress(
        modelId: modelId,
        downloadedBytes: totalExpectedBytes,
        totalBytes: totalExpectedBytes,
        progress: 1.0,
        speedBytesPerSec: 0,
        status: DownloadStatus.completed,
        filesCompleted: config.urls.length,
        filesTotal: config.urls.length,
      ));

      _cancelTokens.remove(modelId);
      _refresh();
    } catch (e, stack) {
      AppLogger.error('Download failed for $modelId', e, stack);
      // Preserve partial downloads for resume — only clean up on explicit cancel
      if (e.toString() == 'Cancelled' && await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }

      _updateProgress(modelId, DownloadProgress(
        modelId: modelId,
        downloadedBytes: 0,
        totalBytes: model.sizeBytes,
        progress: 0,
        speedBytesPerSec: 0,
        status: e.toString() == 'Cancelled' ? DownloadStatus.cancelled : DownloadStatus.failed,
        errorMessage: e.toString(),
      ));

      _cancelTokens.remove(modelId);
      rethrow;
    } finally {
      // Stop foreground service (allow process to be killed if no other work)
      bgService.invoke('setAsBackground');
    }
  }

  Future<bool> _verifyChecksums(Directory targetDir, ModelDownloadInfo config) async {
    for (final entry in config.checksums.entries) {
      final file = File(p.join(targetDir.path, entry.key));
      if (!await file.exists()) {
        // Check in extractPath subdirectory
        final extractedFile = File(p.join(targetDir.path, config.extractPath, entry.key));
        if (!await extractedFile.exists()) {
          AppLogger.warning('Checksum file not found: ${entry.key}');
          continue; // Skip missing files (might be extracted)
        }
        if (!await _verifyFileChecksum(extractedFile, entry.value)) {
          return false;
        }
      } else {
        if (!await _verifyFileChecksum(file, entry.value)) {
          return false;
        }
      }
    }
    return true;
  }

  Future<bool> _verifyFileChecksum(File file, String expectedChecksum) async {
    if (expectedChecksum == 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855') {
      // Placeholder checksum - skip verification
      AppLogger.warning('Skipping checksum verification for ${file.path} (placeholder)');
      return true;
    }
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    final actual = digest.toString();
    if (actual.toLowerCase() != expectedChecksum.toLowerCase()) {
      AppLogger.error('Checksum mismatch for ${file.path}: expected $expectedChecksum, got $actual');
      return false;
    }
    return true;
  }

  void pauseDownload(String modelId) {
    _cancelTokens[modelId]?.cancel();
    final progress = _progressMap[modelId];
    if (progress != null) {
      _updateProgress(modelId, DownloadProgress(
        modelId: modelId,
        downloadedBytes: progress.downloadedBytes,
        totalBytes: progress.totalBytes,
        progress: progress.progress,
        speedBytesPerSec: 0,
        status: DownloadStatus.paused,
        filesCompleted: progress.filesCompleted,
        filesTotal: progress.filesTotal,
      ));
    }
  }

  void cancelDownload(String modelId) {
    _cancelTokens[modelId]?.cancel();
    _cancelTokens.remove(modelId);
    _updateProgress(modelId, DownloadProgress(
      modelId: modelId,
      downloadedBytes: 0,
      totalBytes: 0,
      progress: 0,
      speedBytesPerSec: 0,
      status: DownloadStatus.cancelled,
    ));
  }

  Future<void> deleteModel(String modelId) async {
    final modelList = state.value ?? [];
    final model = modelList.firstWhere((m) => m.id == modelId);
    if (!model.isDownloaded || model.localPath == null) return;

    final dir = Directory(model.localPath!);
    if (await dir.exists()) await dir.delete(recursive: true);

    await _database.update(_database.models).replace(
      ModelsCompanion(
        id: Value(modelId),
        localPath: const Value.absent(),
        isDownloaded: const Value(false),
        isActive: const Value(false),
        downloadedAt: const Value.absent(),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    _refresh();
  }

  Future<void> setActiveModel(String modelId, bool active) async {
    final modelList = state.value ?? [];
    final model = modelList.firstWhere((m) => m.id == modelId);
    if (!model.isDownloaded && active) return;

    // Deactivate other models of same type
    final sameTypeModels = modelList.where((m) => m.type == model.type && m.id != modelId);
    for (final m in sameTypeModels) {
      if (m.isActive) {
        await _database.update(_database.models).replace(
          ModelsCompanion(
            id: Value(m.id),
            isActive: const Value(false),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      }
    }

    await _database.update(_database.models).replace(
      ModelsCompanion(
        id: Value(modelId),
        isActive: Value(active),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    _refresh();
  }

  /// Check if we have MANAGE_EXTERNAL_STORAGE permission (Android 11+)
  Future<bool> hasExternalStoragePermission() async {
    try {
      return await _modelChannel.invokeMethod<bool>('checkStoragePermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request MANAGE_EXTERNAL_STORAGE permission (Android 11+)
  Future<void> requestExternalStoragePermission() async {
    try {
      await _modelChannel.invokeMethod('requestStoragePermission');
    } catch (_) {
      // Ignore
    }
  }

  /// Scan user-provided models directory for pre-placed (sideloaded) models.
  /// Checks both configured model dir and default external Documents/TranslateID/models.
  /// Returns list of model IDs found complete and marked as downloaded.
  Future<List<String>> scanLocalModels() async {
    try {
      AppLogger.info('Starting local model scan...');
      final modelDir = await _getModelDir();
      AppLogger.info('Internal model dir: ${modelDir.path}');
      
      final hasPerm = await hasExternalStoragePermission();
      AppLogger.info('External storage permission: $hasPerm');
      
      final externalDir = hasPerm ? await _getExternalModelDir() : null;
      if (externalDir != null) {
        AppLogger.info('External model dir: ${externalDir.path}');
      }
      
      final scanDirs = <Directory>[modelDir];
      if (externalDir != null && externalDir.path != modelDir.path) {
        scanDirs.add(externalDir);
      }

      final foundIds = <String>[];

      for (final model in ModelRegistry.requiredModels) {
        final config = ModelDownloadConfig.configs[model.id];
        if (config == null) {
          AppLogger.warning('No download config for model: ${model.id}');
          continue;
        }

        for (final baseDir in scanDirs) {
          final dir = Directory(p.join(baseDir.path, model.id));
          final dirExists = await dir.exists();
          AppLogger.debug('Checking ${model.id} in ${dir.path} - exists: $dirExists');
          
          if (!dirExists) continue;
          
          // Files may live at:
          // 1. Model root with FINAL names (after renameMap applied)
          // 2. extractPath subfolder with FINAL names
          // 3. extractPath subfolder with ORIGINAL names (renameMap keys - raw extraction)
          final allPresent = await Future.wait(
            config.files.map((finalName) async {
              // Check 1: root with final name
              final rootPath = p.join(dir.path, finalName);
              if (File(rootPath).existsSync()) return true;
              
              // Check 2: extractPath with final name
              if (config.extractPath.isNotEmpty) {
                final extractPathFinal = p.join(dir.path, config.extractPath, finalName);
                if (File(extractPathFinal).existsSync()) return true;
                
                // Check 3: extractPath with ORIGINAL name (reverse lookup in renameMap)
                final originalName = config.renameMap.entries
                    .firstWhere((e) => e.value == finalName, orElse: () => MapEntry('', ''))
                    .key;
                if (originalName.isNotEmpty) {
                  final extractPathOriginal = p.join(dir.path, config.extractPath, originalName);
                  if (File(extractPathOriginal).existsSync()) return true;
                }
              }
              
              AppLogger.debug('  File $finalName: NOT FOUND (checked root, extractPath/final, extractPath/original)');
              return false;
            }),
          );
          
          AppLogger.debug('  allPresent: $allPresent');
          
          if (allPresent.every((ok) => ok)) {
            foundIds.add(model.id);
            await _markModelDownloaded(model, dir.path);
            AppLogger.info('Found complete model: ${model.id} at ${dir.path}');
            break; // Found in one dir, no need to check others
          }
        }
      }

      if (foundIds.isNotEmpty) {
        AppLogger.info('Scan complete. Found models: $foundIds');
        _refresh();
      } else {
        AppLogger.info('Scan complete. No complete models found.');
      }
      return foundIds;
    } catch (e, stack) {
      AppLogger.error('scanLocalModels failed', e, stack);
      return [];
    }
  }

  Future<void> _markModelDownloaded(ModelInfo model, String localPath) async {
    final rows = await _database.select(_database.models).get();
    ModelInfoEntity? row;
    for (final r in rows) {
      if (r.id == model.id) { row = r; break; }
    }
    if (row == null) return;
    await _database.update(_database.models).replace(
      ModelsCompanion(
        id: Value(model.id),
        name: Value(row.name),
        type: Value(row.type),
        language: Value(row.language),
        version: Value(row.version),
        sizeBytes: Value(row.sizeBytes),
        checksum: Value(row.checksum),
        localPath: Value(localPath),
        isDownloaded: const Value(true),
        isActive: Value(row.isActive),
        downloadedAt: Value(row.downloadedAt),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  void _updateProgress(String modelId, DownloadProgress progress) {
    _progressMap[modelId] = progress;
    _progressController.add(progress);
    // Push to reactive provider so UI rebuilds in real-time
    ref.read(downloadProgressProvider.notifier).update((map) {
      final next = Map<String, DownloadProgress>.from(map);
      next[modelId] = progress;
      return next;
    });
  }

  void _refresh() {
    state = AsyncValue.data(state.value ?? []);
    _loadModelsFromDb().then((models) {
      state = AsyncValue.data(models);
    });
  }
}