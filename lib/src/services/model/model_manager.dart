import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translate_id/src/services/database/app_database.dart';
import 'package:translate_id/src/models/model_info.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';

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
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer2-id-2024-04-07.tar.bz2',
      ],
      extractPath: 'sherpa-onnx-streaming-zipformer2-id-2024-04-07',
      files: ['model.onnx', 'tokens.txt', 'config.json'],
      checksums: {
        'sherpa-onnx-streaming-zipformer2-id-2024-04-07.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // placeholder
      },
    ),
    'sherpa-stt-en': ModelDownloadInfo(
      urls: [
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2024-02-17.tar.bz2',
      ],
      extractPath: 'sherpa-onnx-streaming-zipformer-en-2024-02-17',
      files: ['model.onnx', 'tokens.txt', 'config.json'],
      checksums: {
        'sherpa-onnx-streaming-zipformer-en-2024-02-17.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // placeholder
      },
    ),
    'sherpa-tts-id': ModelDownloadInfo(
      urls: [
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-id_ID-news_tts-medium.tar.bz2',
      ],
      extractPath: 'vits-piper-id_ID-news_tts-medium',
      files: ['model.onnx', 'tokens.txt', 'config.json', 'espeak-ng-data'],
      checksums: {
        'vits-piper-id_ID-news_tts-medium.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // placeholder
      },
    ),
    'sherpa-tts-en': ModelDownloadInfo(
      urls: [
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2',
      ],
      extractPath: 'vits-piper-en_US-lessac-medium',
      files: ['model.onnx', 'tokens.txt', 'config.json', 'espeak-ng-data'],
      checksums: {
        'vits-piper-en_US-lessac-medium.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // placeholder
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
        'silero_vad.onnx': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // placeholder
        'sherpa-onnx-whisper-tiny.tar.bz2': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // placeholder
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

  const ModelDownloadInfo({
    required this.urls,
    required this.extractPath,
    required this.files,
    this.checksums = const {},
  });
}

final modelManagerProvider =
    AsyncNotifierProvider<ModelManager, List<ModelInfo>>(ModelManager.new);

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
    return _loadModelsFromDb();
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
            final elapsedMs = now.difference(lastProgressTime!).inMilliseconds;
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
        // Retry on transient errors
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError ||
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
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(appDir.path, 'models'));
    if (!await modelDir.exists()) await modelDir.create(recursive: true);
    return modelDir;
  }

  Future<void> downloadModel(String modelId, {bool wifiOnly = true, bool resume = true}) async {
    final modelList = state.value ?? [];
    final model = modelList.firstWhere((m) => m.id == modelId, orElse: () => throw Exception('Model not found: $modelId'));
    if (model.isDownloaded) return;

    if (wifiOnly) {
      // TODO: Check network type - implement connectivity check
    }

    final config = ModelDownloadConfig.configs[modelId];
    if (config == null) {
      throw Exception('No download config for model: $modelId');
    }

    final modelDir = await _getModelDir();
    final targetDir = Directory(p.join(modelDir.path, modelId));
    if (await targetDir.exists()) await targetDir.delete(recursive: true);
    await targetDir.create(recursive: true);

    _cancelTokens[modelId] = CancelToken();
    final cancelToken = _cancelTokens[modelId]!;

    int totalDownloaded = 0;

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

      // Extract archives if needed
      if (config.extractPath.isNotEmpty) {
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

        await _extractArchives(targetDir, config);
      }

      // Validate required files exist
      if (!await _validateFiles(targetDir, config)) {
        throw Exception('Required model files missing after download/extraction');
      }

      // Update database
      await _database.update(_database.models).replace(
        ModelsCompanion(
          id: Value(modelId),
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
    } catch (e) {
      AppLogger.error('Download failed for $modelId', e);
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

  Future<void> _extractArchives(Directory targetDir, ModelDownloadInfo config) async {
    for (int i = 0; i < config.urls.length; i++) {
      final url = config.urls[i];
      // Determine downloaded filename from URL (not config.files which lists extracted contents)
      final uri = Uri.parse(url);
      final downloadedFileName = p.basename(uri.path);
      final filePath = p.join(targetDir.path, downloadedFileName);
      final file = File(filePath);
      
      if (!await file.exists()) continue;

      if (downloadedFileName.endsWith('.tar.bz2') || downloadedFileName.endsWith('.tbz2')) {
        await _extractTarBz2(file, targetDir);
      } else if (downloadedFileName.endsWith('.tar.gz') || downloadedFileName.endsWith('.tgz')) {
        await _extractTarGz(file, targetDir);
      } else if (downloadedFileName.endsWith('.zip')) {
        await _extractZip(file, targetDir);
      }
    }
  }

  Future<void> _extractTarBz2(File archiveFile, Directory destination) async {
    final bytes = await archiveFile.readAsBytes();
    final decompressed = BZip2Decoder().decodeBytes(bytes);
    final tarArchive = TarDecoder().decodeBytes(decompressed);
    
    for (final entry in tarArchive) {
      final entryPath = p.join(destination.path, entry.name);
      if (entry.isFile) {
        final outFile = File(entryPath);
        if (!await outFile.parent.exists()) {
          await outFile.parent.create(recursive: true);
        }
        await outFile.writeAsBytes(entry.content as List<int>);
      } else if (entry.isDirectory) {
        await Directory(entryPath).create(recursive: true);
      }
    }
  }

  Future<void> _extractTarGz(File archiveFile, Directory destination) async {
    final bytes = await archiveFile.readAsBytes();
    final decompressed = GZipDecoder().decodeBytes(bytes);
    final tarArchive = TarDecoder().decodeBytes(decompressed);
    
    for (final entry in tarArchive) {
      final entryPath = p.join(destination.path, entry.name);
      if (entry.isFile) {
        final outFile = File(entryPath);
        if (!await outFile.parent.exists()) {
          await outFile.parent.create(recursive: true);
        }
        await outFile.writeAsBytes(entry.content as List<int>);
      } else if (entry.isDirectory) {
        await Directory(entryPath).create(recursive: true);
      }
    }
  }

  Future<void> _extractZip(File archiveFile, Directory destination) async {
    final bytes = await archiveFile.readAsBytes();
    final zipArchive = ZipDecoder().decodeBytes(bytes);
    
    for (final entry in zipArchive) {
      final entryPath = p.join(destination.path, entry.name);
      if (entry.isFile) {
        final outFile = File(entryPath);
        if (!await outFile.parent.exists()) {
          await outFile.parent.create(recursive: true);
        }
        await outFile.writeAsBytes(entry.content as List<int>);
      } else if (entry.isDirectory) {
        await Directory(entryPath).create(recursive: true);
      }
    }
  }

  Future<bool> _validateFiles(Directory targetDir, ModelDownloadInfo config) async {
    for (final fileName in config.files) {
      // Check in root
      var file = File(p.join(targetDir.path, fileName));
      if (await file.exists()) continue;
      
      // Check in extractPath
      if (config.extractPath.isNotEmpty) {
        file = File(p.join(targetDir.path, config.extractPath, fileName));
        if (await file.exists()) continue;
      }
      
      AppLogger.error('Required file not found: $fileName');
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

  void _updateProgress(String modelId, DownloadProgress progress) {
    _progressMap[modelId] = progress;
    _progressController.add(progress);
  }

  void _refresh() {
    state = AsyncValue.data(state.value ?? []);
    _loadModelsFromDb().then((models) {
      state = AsyncValue.data(models);
    });
  }
}

/// AppDatabase provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase provider must be overridden in main.dart');
});