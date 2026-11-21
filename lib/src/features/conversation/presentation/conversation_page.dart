import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/shared/widgets/voice_button.dart';
import 'package:translate_id/src/services/voice/voice_engine.dart';
import 'package:translate_id/src/features/translation/providers/translation_providers.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key});

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  String _langA = 'en';
  String _langB = 'id';
  bool _isListeningA = false;
  bool _isListeningB = false;
  
  StreamSubscription? _sttSubA;
  StreamSubscription? _sttSubB;
  StreamSubscription? _sttFinalSubA;
  StreamSubscription? _sttFinalSubB;
  VoiceEngine? _voiceEngine;
  bool _voiceEngineReady = false;

  @override
  void initState() {
    super.initState();
    _initVoiceEngine();
  }

  Future<void> _initVoiceEngine() async {
    _voiceEngine = ref.read(voiceEngineProvider);
    try {
      await _voiceEngine!.initialize();
      if (mounted) setState(() => _voiceEngineReady = true);
    } catch (e) {
      debugPrint('VoiceEngine init failed: $e');
    }
  }

  @override
  void dispose() {
    _sttSubA?.cancel();
    _sttSubB?.cancel();
    _sttFinalSubA?.cancel();
    _sttFinalSubB?.cancel();
    _voiceEngine?.destroyRecognizer();
    _voiceEngine?.destroyTts();
    super.dispose();
  }

  Future<void> _toggleListening(String side) async {
    if (!_voiceEngineReady || _voiceEngine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model STT belum siap. Buka Pengaturan > Model.')),
      );
      return;
    }

    final isA = side == 'A';
    final sourceLang = isA ? _langA : _langB;
    final targetLang = isA ? _langB : _langA;
    final sttId = 'stt_conv_$side';

    if (isA ? _isListeningA : _isListeningB) {
      // Stop listening
      setState(() {
        if (isA) _isListeningA = false;
        else _isListeningB = false;
      });
      await _voiceEngine!.destroyRecognizer();
      return;
    }

    // Start listening
    setState(() {
      if (isA) {
        _isListeningA = true;
        _isListeningB = false;
      } else {
        _isListeningB = true;
        _isListeningA = false;
      }
    });

    try {
      final created = await _voiceEngine!.createRecognizer(sourceLang);
      if (!created) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model STT belum diunduh. Buka Pengaturan > Model.')),
          );
        }
        setState(() {
          if (isA) _isListeningA = false;
          else _isListeningB = false;
        });
        return;
      }

      // Listen to partial results
      _sttSubA?.cancel();
      _sttSubB?.cancel();
      if (isA) {
        _sttSubA = _voiceEngine!.sttPartialStream.listen((result) {
          // Update UI with partial text
        });
        _sttFinalSubA = _voiceEngine!.sttFinalStream.listen((result) async {
          if (!mounted) return;
          if (result.text.trim().isEmpty) return;
          
          // Translate and speak
          await _translateAndSpeak(result.text, sourceLang, targetLang);
        });
      } else {
        _sttSubB = _voiceEngine!.sttPartialStream.listen((result) {
          // Update UI with partial text
        });
        _sttFinalSubB = _voiceEngine!.sttFinalStream.listen((result) async {
          if (!mounted) return;
          if (result.text.trim().isEmpty) return;
          
          await _translateAndSpeak(result.text, sourceLang, targetLang);
        });
      }
    } catch (e) {
      debugPrint('Conversation STT error: $e');
      if (mounted) {
        setState(() {
          if (isA) _isListeningA = false;
          else _isListeningB = false;
        });
      }
    }
  }

  Future<void> _translateAndSpeak(String text, String sourceLang, String targetLang) async {
    try {
      // Translate
      final engine = ref.read(translationEngineProvider);
      final result = await engine.translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );

      // Speak translation
      final voiceEngine = ref.read(voiceEngineProvider);
      await voiceEngine.createTts(targetLang);
      await voiceEngine.generateTts(result.text);
    } catch (e) {
      debugPrint('Translate+Speak error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Percakapan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => setState(() {
              final temp = _langA;
              _langA = _langB;
              _langB = temp;
            }),
            tooltip: 'Tukar bahasa',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Conversation settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Language indicators
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LanguageIndicator(
                    lang: _langA,
                    label: 'Anda',
                    isListening: _isListeningA,
                    onTap: () => _toggleListening('A'),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  child: _LanguageIndicator(
                    lang: _langB,
                    label: 'Lawan bicara',
                    isListening: _isListeningB,
                    onTap: () => _toggleListening('B'),
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ),

          // Conversation history
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: true,
              itemCount: 0, // TODO: Load from database
              itemBuilder: (context, index) {
                return _ConversationBubble(
                  text: 'Contoh pesan',
                  translatedText: 'Contoh terjemahan',
                  isMe: index % 2 == 0,
                  timestamp: DateTime.now(),
                );
              },
            ),
          ),

          // Bottom controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: VoiceButton(
                    state: _isListeningA ? VoiceButtonState.listening : VoiceButtonState.idle,
                    onTap: _voiceEngineReady ? () => _toggleListening('A') : null,
                    size: 56,
                  ),
                ),
                const Gap(24),
                Expanded(
                  child: VoiceButton(
                    state: _isListeningB ? VoiceButtonState.listening : VoiceButtonState.idle,
                    onTap: _voiceEngineReady ? () => _toggleListening('B') : null,
                    size: 56,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageIndicator extends StatelessWidget {
  final String lang;
  final String label;
  final bool isListening;
  final VoidCallback onTap;
  final bool alignRight;

  const _LanguageIndicator({
    required this.lang,
    required this.label,
    required this.isListening,
    required this.onTap,
    this.alignRight = false,
  });

  static const Map<String, String> _langFlags = {
    'en': '🇺🇸',
    'id': '🇮🇩',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isListening ? Colors.red.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isListening ? Border.all(color: Colors.red, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_langFlags[lang]!, style: const TextStyle(fontSize: 24)),
                const Gap(8),
                Text(
                  lang.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isListening ? Colors.red : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const Gap(4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isListening)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ).animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 1000.ms, color: Colors.red.withOpacity(0.5)),
                const Gap(4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isListening) ...[
                  const Gap(4),
                  const Text('Mendengarkan...',
                      style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationBubble extends StatelessWidget {
  final String text;
  final String translatedText;
  final bool isMe;
  final DateTime timestamp;

  const _ConversationBubble({
    required this.text,
    required this.translatedText,
    required this.isMe,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryTeal.withOpacity(0.2),
              child: Icon(Icons.person, size: 16, color: AppTheme.primaryTeal),
            ),
            const Gap(8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryTeal : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: !isMe ? Border.all(color: theme.dividerColor) : null,
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isMe ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    translatedText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isMe ? Colors.white.withOpacity(0.8) : theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const Gap(8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryTeal,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}