import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';

/// OCR Result with bounding boxes
class OcrResult {
  final String text;
  final List<TextBlock> blocks;
  final ui.Size imageSize;
  final Duration latency;

  const OcrResult({
    required this.text,
    required this.blocks,
    required this.imageSize,
    required this.latency,
  });

  factory OcrResult.fromMap(Map<dynamic, dynamic> map) {
    final rawBlocks = (map['blocks'] as List<dynamic>?) ?? [];
    final blocks = rawBlocks.map((b) {
      final m = b as Map<dynamic, dynamic>;
      final corners = (m['corners'] as List<dynamic>?) ?? [];
      return TextBlock(
        text: m['text'] as String? ?? '',
        boundingBox: ui.Rect.fromLTRB(
          (m['left'] as num?)?.toDouble() ?? 0,
          (m['top'] as num?)?.toDouble() ?? 0,
          (m['right'] as num?)?.toDouble() ?? 0,
          (m['bottom'] as num?)?.toDouble() ?? 0,
        ),
        cornerPoints: corners.map((c) {
          final pair = c as List<dynamic>;
          return Offset(
            (pair[0] as num).toDouble(),
            (pair[1] as num).toDouble(),
          );
        }).toList(),
        confidence: (m['confidence'] as num?)?.toDouble() ?? 1.0,
        language: m['language'] as String? ?? 'en',
      );
    }).toList();

    return OcrResult(
      text: map['text'] as String? ?? '',
      blocks: blocks,
      imageSize: ui.Size(
        width: (map['imageWidth'] as num?)?.toDouble() ?? 0,
        height: (map['imageHeight'] as num?)?.toDouble() ?? 0,
      ),
      latency: Duration(milliseconds: (map['latency'] as num?)?.toInt() ?? 0),
    );
  }
}

/// Text block with bounding box
class TextBlock {
  final String text;
  final ui.Rect boundingBox; // normalized 0-1
  final List<Offset> cornerPoints; // 4 corners
  final double confidence;
  final String language;

  const TextBlock({
    required this.text,
    required this.boundingBox,
    required this.cornerPoints,
    required this.confidence,
    required this.language,
  });

  /// Convert normalized coordinates to pixel coordinates
  ui.Rect toPixelRect(ui.Size imageSize) {
    return ui.Rect.fromLTRB(
      boundingBox.left * imageSize.width,
      boundingBox.top * imageSize.height,
      boundingBox.right * imageSize.width,
      boundingBox.bottom * imageSize.height,
    );
  }
}

/// OCR Engine using ML Kit Text Recognition v2 via MethodChannel
class OcrEngine {
  static const _channel = MethodChannel('com.translateid/native');
  bool _initialized = false;

  OcrEngine();

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    AppLogger.info('OcrEngine initialized (ML Kit native bridge)');
  }

  /// Recognize text from image bytes
  Future<OcrResult?> recognizeFromBytes(
    Uint8List imageBytes, {
    ui.Size? imageSize,
    int rotationDegrees = 0,
    String language = 'auto',
  }) async {
    if (!_initialized) await initialize();

    final stopwatch = Stopwatch()..start();
    try {
      // ML Kit native expects NV21 rotated frame dimensions.
      // For arbitrary image bytes (e.g. JPEG), pass through path-based API instead.
      final result = await _channel.invokeMethod('ocrFromBytes', {
        'bytes': imageBytes,
        'width': imageSize?.width.toInt() ?? 0,
        'height': imageSize?.height.toInt() ?? 0,
        'rotation': rotationDegrees,
        'language': language,
      });
      stopwatch.stop();

      if (result is Map) {
        return OcrResult.fromMap(result);
      }
    } catch (e) {
      AppLogger.error('OCR from bytes failed', e);
    }
    return null;
  }

  /// Recognize text from camera frame (for real-time)
  Future<OcrResult?> recognizeFromCamera(Uint8List frameBytes, ui.Size frameSize) async {
    return recognizeFromBytes(frameBytes, imageSize: frameSize, language: 'auto');
  }

  /// Recognize text from file path
  Future<OcrResult?> recognizeFromFile(String filePath, {String language = 'auto'}) async {
    if (!_initialized) await initialize();

    final stopwatch = Stopwatch()..start();
    try {
      final result = await _channel.invokeMethod('ocrFromBitmap', {
        'path': filePath,
        'language': language,
      });
      stopwatch.stop();

      if (result is Map) {
        return OcrResult.fromMap(result);
      }
    } catch (e) {
      AppLogger.error('OCR from file failed', e);
    }
    return null;
  }

  /// Get supported languages
  List<String> getSupportedLanguages() {
    return ['en', 'id', 'zh', 'ja', 'ko', 'auto'];
  }

  void dispose() {
    // Recognizers closed natively when engine torn down
  }
}