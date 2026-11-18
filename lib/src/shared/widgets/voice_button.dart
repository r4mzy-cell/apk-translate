import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';

enum VoiceButtonState { idle, listening, processing, speaking }

class VoiceButton extends StatefulWidget {
  final VoiceButtonState state;
  final VoidCallback onTap;
  final double size;

  const VoiceButton({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 64,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color iconColor;
    IconData iconData;

    switch (widget.state) {
      case VoiceButtonState.idle:
        backgroundColor = AppTheme.primaryTeal;
        iconColor = isDark ? AppTheme.primaryDark : Colors.white;
        iconData = Icons.mic;
        break;
      case VoiceButtonState.listening:
        backgroundColor = Colors.red;
        iconColor = Colors.white;
        iconData = Icons.mic;
        break;
      case VoiceButtonState.processing:
        backgroundColor = Colors.orange;
        iconColor = Colors.white;
        iconData = Icons.hourglass_empty;
        break;
      case VoiceButtonState.speaking:
        backgroundColor = Colors.blue;
        iconColor = Colors.white;
        iconData = Icons.volume_up;
        break;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Wave animation for listening
          if (widget.state == VoiceButtonState.listening)
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Container(
                  width: widget.size + _waveController.value * 40,
                  height: widget.size + _waveController.value * 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.3 * (1 - _waveController.value)),
                  ),
                );
              },
            ),

          // Pulse animation for processing
          if (widget.state == VoiceButtonState.processing)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: widget.size + _pulseController.value * 20,
                  height: widget.size + _pulseController.value * 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.3 * (1 - _pulseController.value)),
                  ),
                );
              },
            ),

          // Main button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: widget.size * 0.5,
            ),
          ).animate(
            target: widget.state != VoiceButtonState.idle ? 1 : 0,
          ).scale(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
          ),

          // Rotating icon for processing
          if (widget.state == VoiceButtonState.processing)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _pulseController.value * 6.28,
                  child: Icon(
                    Icons.sync,
                    color: iconColor,
                    size: widget.size * 0.45,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Floating voice button for overlay
class FloatingVoiceButton extends StatefulWidget {
  final VoiceButtonState state;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;

  const FloatingVoiceButton({
    super.key,
    required this.state,
    required this.onTap,
    this.onLongPress,
    this.size = 56,
  });

  @override
  State<FloatingVoiceButton> createState() => _FloatingVoiceButtonState();
}

class _FloatingVoiceButtonState extends State<FloatingVoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _dragController;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onPanStart: (_) => _dragController.forward(),
      onPanEnd: (_) => _dragController.reverse(),
      child: AnimatedBuilder(
        animation: _dragController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - _dragController.value * 0.1,
            child: VoiceButton(
              state: widget.state,
              onTap: widget.onTap,
              size: widget.size,
            ),
          );
        },
      ),
    );
  }
}