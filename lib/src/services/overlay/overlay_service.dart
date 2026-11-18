import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';

part 'overlay_service.g.dart';

/// Overlay types
enum OverlayType {
  /// Floating bubble (chat head) - always visible
  floatingBubble,
  /// Screenshot translation bubble - appears at text position
  screenshotBubble,
  /// Live screen translate - replaces text on screen
  liveTranslate,
  /// Audio subtitle overlay
  audioSubtitle,
}

/// Overlay state
class OverlayState {
  final OverlayType type;
  final bool isEnabled;
  final Map<String, dynamic> config;

  const OverlayState({
    required this.type,
    required this.isEnabled,
    this.config = const {},
  });

  OverlayState copyWith({
    bool? isEnabled,
    Map<String, dynamic>? config,
  }) {
    return OverlayState(
      type: type,
      isEnabled: isEnabled ?? this.isEnabled,
      config: config ?? this.config,
    );
  }
}

/// Bubble position
class BubblePosition {
  final double x;
  final double y;
  final double width;
  final double height;

  const BubblePosition({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Translation overlay item
class TranslationOverlay {
  final String id;
  final String originalText;
  final String translatedText;
  final Rect bounds; // normalized 0-1
  final OverlayType type;
  final DateTime createdAt;

  const TranslationOverlay({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.bounds,
    required this.type,
    required this.createdAt,
  });
}

class Rect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const Rect({required this.left, required this.top, required this.right, required this.bottom});

  factory Rect.fromLTRB(double left, double top, double right, double bottom) {
    return Rect(left: left, top: top, right: right, bottom: bottom);
  }

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

/// Overlay Service - manages all overlay types
class OverlayService {
  final StreamController<OverlayState> _stateController = StreamController.broadcast();
  final StreamController<List<TranslationOverlay>> _overlaysController = StreamController.broadcast();
  final StreamController<BubblePosition> _bubblePositionController = StreamController.broadcast();

  final Map<OverlayType, OverlayState> _states = {};
  final List<TranslationOverlay> _activeOverlays = [];
  BubblePosition? _bubblePosition;

  OverlayService() {
    // Initialize default states
    for (final type in OverlayType.values) {
      _states[type] = OverlayState(type: type, isEnabled: false);
    }
  }

  Stream<OverlayState> get stateStream => _stateController.stream;
  Stream<List<TranslationOverlay>> get overlaysStream => _overlaysController.stream;
  Stream<BubblePosition> get bubblePositionStream => _bubblePositionController.stream;

  OverlayState getState(OverlayType type) => _states[type]!;
  List<TranslationOverlay> get activeOverlays => List.unmodifiable(_activeOverlays);
  BubblePosition? get bubblePosition => _bubblePosition;

  /// Enable/disable an overlay type
  Future<void> setOverlayEnabled(OverlayType type, bool enabled, {Map<String, dynamic>? config}) async {
    final current = _states[type]!;
    _states[type] = current.copyWith(isEnabled: enabled, config: config);
    _stateController.add(_states[type]!);

    if (enabled) {
      await _startOverlay(type);
    } else {
      await _stopOverlay(type);
    }
  }

  /// Toggle overlay
  Future<void> toggleOverlay(OverlayType type) async {
    await setOverlayEnabled(type, !_states[type]!.isEnabled);
  }

  /// Update bubble position
  void updateBubblePosition(BubblePosition position) {
    _bubblePosition = position;
    _bubblePositionController.add(position);
  }

  /// Add translation overlay (for screenshot/live translate)
  void addTranslationOverlay(TranslationOverlay overlay) {
    _activeOverlays.add(overlay);
    _overlaysController.add(List.unmodifiable(_activeOverlays));
  }

  /// Remove translation overlay
  void removeTranslationOverlay(String id) {
    _activeOverlays.removeWhere((o) => o.id == id);
    _overlaysController.add(List.unmodifiable(_activeOverlays));
  }

  /// Clear all overlays
  void clearOverlays() {
    _activeOverlays.clear();
    _overlaysController.add([]);
  }

  /// Start specific overlay (calls native)
  Future<void> _startOverlay(OverlayType type) async {
    AppLogger.info('Starting overlay: $type');
    switch (type) {
      case OverlayType.floatingBubble:
        await _startFloatingBubble();
        break;
      case OverlayType.screenshotBubble:
        await _startScreenshotTranslate();
        break;
      case OverlayType.liveTranslate:
        await _startLiveTranslate();
        break;
      case OverlayType.audioSubtitle:
        await _startAudioSubtitle();
        break;
    }
  }

  /// Stop specific overlay
  Future<void> _stopOverlay(OverlayType type) async {
    AppLogger.info('Stopping overlay: $type');
    switch (type) {
      case OverlayType.floatingBubble:
        await _stopFloatingBubble();
        break;
      case OverlayType.screenshotBubble:
        await _stopScreenshotTranslate();
        break;
      case OverlayType.liveTranslate:
        await _stopLiveTranslate();
        break;
      case OverlayType.audioSubtitle:
        await _stopAudioSubtitle();
        break;
    }
  }

  // Native implementations (via platform channel)
  Future<void> _startFloatingBubble() async {
    // TODO: Call Kotlin to show System Alert Window
  }

  Future<void> _stopFloatingBubble() async {
    // TODO: Call Kotlin to hide System Alert Window
  }

  Future<void> _startScreenshotTranslate() async {
    // TODO: Call Kotlin to request MediaProjection + capture screenshot
  }

  Future<void> _stopScreenshotTranslate() async {
    // TODO: Call Kotlin to stop MediaProjection
  }

  Future<void> _startLiveTranslate() async {
    // TODO: Call Kotlin to start AccessibilityService + MediaProjection loop
  }

  Future<void> _stopLiveTranslate() async {
    // TODO: Call Kotlin to stop AccessibilityService + MediaProjection
  }

  Future<void> _startAudioSubtitle() async {
    // TODO: Call Kotlin to start AudioPlaybackCapture
  }

  Future<void> _stopAudioSubtitle() async {
    // TODO: Call Kotlin to stop AudioPlaybackCapture
  }

  /// Take screenshot and translate (for screenshot bubble mode)
  Future<void> captureAndTranslate() async {
    AppLogger.info('Capture and translate requested');
    // TODO: Trigger screenshot via MediaProjection, then OCR + translate
  }

  /// Translate system audio (for audio subtitle mode)
  Future<void> startAudioTranslation() async {
    AppLogger.info('Start audio translation requested');
    // TODO: Start AudioPlaybackCapture -> STT -> Translate -> Subtitle
  }

  void dispose() {
    _stateController.close();
    _overlaysController.close();
    _bubblePositionController.close();
  }
}