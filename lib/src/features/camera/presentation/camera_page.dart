import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/services/ocr/ocr_engine.dart';
import 'package:translate_id/src/features/translation/providers/translation_providers.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isProcessing = false;
  bool _torchOn = false;
  bool _showOverlay = true;
  List<TextBlock> _detectedBlocks = [];
  String _translatedText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _selectedCameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      _controller = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
      _startOcrStream();
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _startOcrStream() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _controller!.startImageStream((CameraImage image) {
      if (_isProcessing || !_showOverlay) return;
      _processFrame(image);
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    _isProcessing = true;
    try {
      final ocrEngine = ref.read(ocrEngineProvider);
      
      // Convert YUV420 to bytes for OCR
      final bytes = _convertYUV420ToBytes(image);
      if (bytes == null) return;

      final result = await ocrEngine.recognizeFromCamera(
        bytes,
        ui.Size(image.width.toDouble(), image.height.toDouble()),
      );

      if (mounted && result != null && result.blocks.isNotEmpty) {
        setState(() {
          _detectedBlocks = result.blocks;
        });
      }
    } catch (e) {
      debugPrint('OCR frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Uint8List? _convertYUV420ToBytes(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int yRowStride = image.planes[0].bytesPerRow;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      final yBuffer = image.planes[0].bytes;
      final uBuffer = image.planes[1].bytes;
      final vBuffer = image.planes[2].bytes;

      final nv21 = Uint8List(width * height * 3 ~/ 2);
      int index = 0;

      // Y plane
      for (int i = 0; i < height; i++) {
        nv21.setRange(index, index + width, yBuffer.buffer.asUint8List(yRowStride * i, width));
        index += width;
      }

      // UV plane (interleaved VU for NV21)
      for (int i = 0; i < height ~/ 2; i++) {
        for (int j = 0; j < width ~/ 2; j++) {
          final uIndex = uvRowStride * i + uvPixelStride * j;
          final vIndex = uvRowStride * i + uvPixelStride * j;
          if (uIndex < uBuffer.length && vIndex < vBuffer.length) {
            nv21[index++] = vBuffer[vIndex];
            nv21[index++] = uBuffer[uIndex];
          }
        }
      }

      return nv21;
    } catch (e) {
      debugPrint('YUV conversion error: $e');
      return null;
    }
  }

  Future<void> _captureAndTranslate() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isProcessing = true);
    try {
      final XFile photo = await _controller!.takePicture();
      
      final ocrEngine = ref.read(ocrEngineProvider);
      final result = await ocrEngine.recognizeFromFile(photo.path, language: 'auto');

      if (result != null && result.text.isNotEmpty) {
        // Translate the detected text
        final engine = ref.read(translationEngineProvider);
        final translation = await engine.translate(
          text: result.text,
          sourceLang: result.blocks.firstOrNull?.language ?? 'auto',
          targetLang: 'id',
        );

        if (mounted) {
          setState(() {
            _translatedText = translation.text;
            _showResultBottomSheet(result.text, translation.text);
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada teks terdeteksi')),
          );
        }
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultBottomSheet(String originalText, String translatedText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResultSheet(
        originalText: originalText,
        translatedText: translatedText,
        onCopy: () {
          Navigator.pop(context);
          // Copy to clipboard
        },
        onSpeak: () {
          Navigator.pop(context);
          // TTS
        },
        onSave: () {
          Navigator.pop(context);
          // Save to phrasebook
        },
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() => _isProcessing = true);
        try {
          final ocrEngine = ref.read(ocrEngineProvider);
          final result = await ocrEngine.recognizeFromFile(image.path, language: 'auto');

          if (result != null && result.text.isNotEmpty) {
            final engine = ref.read(translationEngineProvider);
            final translation = await engine.translate(
              text: result.text,
              sourceLang: result.blocks.firstOrNull?.language ?? 'auto',
              targetLang: 'id',
            );

            if (mounted) {
              setState(() {
                _translatedText = translation.text;
                _showResultBottomSheet(result.text, translation.text);
              });
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak ada teks terdeteksi')),
              );
            }
          }
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      }
    } catch (e) {
      debugPrint('Gallery picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    }
  }

  Future<void> _toggleTorch() async {
    if (_controller == null) return;
    try {
      await _controller!.setFlashMode(_torchOn ? FlashMode.off : FlashMode.torch);
      setState(() => _torchOn = !_torchOn);
    } catch (e) {
      debugPrint('Torch error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    _selectedCameraIndex = newIndex;
    await _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kamera OCR'),
        actions: [
          IconButton(
            icon: Icon(_showOverlay ? Icons.layers_outlined : Icons.layers_clear_outlined),
            onPressed: () => setState(() => _showOverlay = !_showOverlay),
            tooltip: _showOverlay ? 'Sembunyikan overlay' : 'Tampilkan overlay',
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _pickFromGallery,
            tooltip: 'Pilih dari galeri',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(_controller!),
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),

          // OCR Overlay
          if (_showOverlay && _detectedBlocks.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: _OcrOverlayPainter(
                  blocks: _detectedBlocks,
                  previewSize: _controller?.value.previewSize,
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status
                  if (_detectedBlocks.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_detectedBlocks.length} teks terdeteksi',
                        style: theme.textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),

                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                        label: 'Lampu',
                        onTap: _toggleTorch,
                        active: _torchOn,
                      ),
                      _ControlButton(
                        icon: Icons.camera,
                        label: 'Ambil',
                        onTap: _captureAndTranslate,
                        isMain: true,
                        loading: _isProcessing,
                      ),
                      _ControlButton(
                        icon: Icons.flip_camera_ios,
                        label: 'Ganti',
                        onTap: _switchCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OcrOverlayPainter extends CustomPainter {
  final List<TextBlock> blocks;
  final Size? previewSize;

  _OcrOverlayPainter({required this.blocks, this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.primaryTeal;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppTheme.primaryTeal.withOpacity(0.15);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (final block in blocks) {
      Rect scaledRect = block.boundingBox;
      if (previewSize != null) {
        final scaleX = size.width / previewSize!.width;
        final scaleY = size.height / previewSize!.height;
        scaledRect = Rect.fromLTRB(
          block.boundingBox.left * scaleX,
          block.boundingBox.top * scaleY,
          block.boundingBox.right * scaleX,
          block.boundingBox.bottom * scaleY,
        );
      }

      // Draw bounding box
      canvas.drawRect(scaledRect, paint);
      canvas.drawRect(scaledRect, fillPaint);

      // Draw label
      textPainter.text = TextSpan(
        text: block.text.length > 30 ? '${block.text.substring(0, 30)}...' : block.text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 2)],
        ),
      );
      textPainter.layout(minWidth: 0, maxWidth: scaledRect.width - 8);
      textPainter.paint(
        canvas,
        Offset(scaledRect.left + 4, scaledRect.top - textPainter.height - 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool isMain;
  final bool loading;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.isMain = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isMain) {
      return GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: loading ? 56 : 72,
          height: 72,
          decoration: BoxDecoration(
            shape: loading ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: loading ? null : BorderRadius.circular(36),
            color: loading ? AppTheme.primaryTeal.withOpacity(0.7) : AppTheme.primaryTeal,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryTeal.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: loading
              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    const Gap(2),
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppTheme.primaryTeal : Colors.white.withOpacity(0.9),
              border: Border.all(color: active ? AppTheme.primaryTeal : Colors.transparent, width: 2),
            ),
            child: Icon(
              icon,
              color: active ? Colors.white : theme.colorScheme.onSurface,
              size: 26,
            ),
          ),
        ),
        const Gap(4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ResultSheet extends StatelessWidget {
  final String originalText;
  final String translatedText;
  final VoidCallback onCopy;
  final VoidCallback onSpeak;
  final VoidCallback onSave;

  const _ResultSheet({
    required this.originalText,
    required this.translatedText,
    required this.onCopy,
    required this.onSpeak,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),
          Row(
            children: [
              Text('Hasil Terjemahan', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Gap(16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Teks Asli:', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Gap(4),
                SelectableText(originalText, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const Gap(12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terjemahan:', style: theme.textTheme.labelMedium?.copyWith(color: AppTheme.primaryTeal)),
                const Gap(4),
                SelectableText(translatedText, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Gap(16),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.content_copy), label: const Text('Salin'), onPressed: onCopy)),
              const Gap(12),
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.volume_up), label: const Text('Dengarkan'), onPressed: onSpeak)),
              const Gap(12),
              Expanded(child: FilledButton.icon(icon: const Icon(Icons.star_border), label: const Text('Simpan'), onPressed: onSave)),
            ],
          ),
        ],
      ),
    );
  }
}