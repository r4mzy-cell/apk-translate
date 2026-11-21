import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/features/translation/providers/translation_providers.dart';
import 'package:translate_id/src/services/voice/voice_engine.dart';
import 'package:translate_id/src/services/ocr/ocr_engine.dart';
import 'package:translate_id/src/shared/widgets/language_selector.dart';
import 'package:translate_id/src/shared/widgets/translation_input.dart';
import 'package:translate_id/src/shared/widgets/translation_output.dart';
import 'package:translate_id/src/shared/enums/formality_mode.dart';
import 'package:translate_id/src/shared/widgets/formality_toggle.dart';
import 'package:translate_id/src/features/settings/providers/settings_providers.dart';
import 'package:translate_id/src/services/database/app_database.dart';
import 'package:translate_id/src/features/history/presentation/history_page.dart';
import 'package:translate_id/src/features/camera/presentation/camera_page.dart';

class TranslationPage extends ConsumerStatefulWidget {
  const TranslationPage({super.key});

  @override
  ConsumerState<TranslationPage> createState() => _TranslationPageState();
}

class _TranslationPageState extends ConsumerState<TranslationPage> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  late AnimationController _swapAnimationController;
  String _sourceLang = 'en';
  String _targetLang = 'id';
  FormalityMode _formality = FormalityMode.formal;
  String _translationResult = '';
  bool _isTranslating = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _swapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize engines
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(enginesInitializedProvider.future).then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _swapAnimationController.dispose();
    _debounceCounter = -1; // Cancel any pending debounce
    super.dispose();
  }

  void _swapLanguages() {
    _swapAnimationController.forward().then((_) {
      _swapAnimationController.reverse();
    });
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      // Also swap input and output text
      final tempText = _inputController.text;
      _inputController.text = _translationResult;
      _translationResult = tempText;
    });
  }

  void _onFormalityChanged(FormalityMode mode) {
    setState(() => _formality = mode);
    // Re-translate with new formality if we have a result
    if (_translationResult.isNotEmpty && _inputController.text.isNotEmpty) {
      _translateText(_inputController.text);
    }
  }

  Future<void> _translateText(String text) async {
    if (text.trim().isEmpty) {
      setState(() => _translationResult = '');
      return;
    }

    setState(() => _isTranslating = true);
    
    try {
      final engine = ref.read(translationEngineProvider);
      final result = await engine.translate(
        text: text,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
        formality: _formality,
      );
      
      if (mounted) {
        setState(() {
          _translationResult = result.text;
          _isTranslating = false;
        });
        // Save to history
        await _saveToHistory(text, result.text, 'text');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjemahan gagal: $e')),
        );
      }
    }
  }

  Future<void> _saveToHistory(String source, String target, String type) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.addHistory(
        sourceText: source,
        targetText: target,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
        type: type,
      );
    } catch (e) {
      // Silently fail history save
    }
  }

  Future<void> _onVoiceTap() async {
    if (_isListening) return;
    
    setState(() => _isListening = true);
    
    try {
      final voiceEngine = ref.read(voiceEngineProvider);
      
      // Create recognizer for source language
      final created = await voiceEngine.createRecognizer(_sourceLang);
      if (!created) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model STT belum diunduh. Buka Pengaturan > Model.')),
          );
        }
        setState(() => _isListening = false);
        return;
      }
      
      // Start listening - show a dialog with real-time results
      if (mounted) {
        await _showVoiceInputDialog(voiceEngine);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Input suara gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _showVoiceInputDialog(VoiceEngine voiceEngine) async {
    String partialText = '';
    String finalText = '';
    StreamSubscription? partialSub;
    StreamSubscription? finalSub;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Listen to partial results
          partialSub = voiceEngine.sttPartialStream.listen((result) {
            if (context.mounted) {
              setDialogState(() {
                partialText = result.text;
              });
            }
          });
          
          // Listen to final results
          finalSub = voiceEngine.sttFinalStream.listen((result) {
            if (context.mounted) {
              setDialogState(() {
                finalText = result.text;
                partialText = '';
              });
              // Auto-close after a short delay
              Future.delayed(const Duration(milliseconds: 500), () {
                if (context.mounted) Navigator.pop(context, finalText);
              });
            }
          });
          
          // Cleanup on dialog dispose
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigator = Navigator.of(context);
            navigator.pop().then((_) {
              partialSub?.cancel();
              finalSub?.cancel();
              voiceEngine.resetRecognizer();
            });
          });
          
          return AlertDialog(
            title: const Text('Input Suara'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic,
                  size: 64,
                  color: AppTheme.primaryTeal,
                ).animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 1000.ms, color: AppTheme.primaryTeal.withOpacity(0.5)),
                const Gap(16),
                Text(
                  partialText.isNotEmpty ? partialText : 'Mendengarkan...',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                if (finalText.isNotEmpty)
                  Text(
                    'Terjemahan: $finalText',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final text = finalText.isNotEmpty ? finalText : partialText;
                  if (text.isNotEmpty) {
                    _inputController.text = text;
                    await _translateText(text);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Gunakan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onCameraTap() async {
    // Navigate to full camera OCR page
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );
    // After returning, could refresh if needed
  }

  Future<void> _onPasteTap() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isNotEmpty) {
        _inputController.text = text;
        await _translateText(text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menempel: $e')),
        );
      }
    }
  }

  Future<void> _onCopyResult() async {
    if (_translationResult.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _translationResult));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hasil disalin ke clipboard')),
        );
      }
    }
  }

  Future<void> _onSpeakResult() async {
    if (_translationResult.isEmpty) return;
    
    try {
      final voiceEngine = ref.read(voiceEngineProvider);
      final ttsSpeed = ref.read(ttsSpeedProvider);
      final ttsPitch = ref.read(ttsPitchProvider);
      final ttsVoiceId = ref.read(ttsVoiceIdProvider);
      
      // Create TTS for target language
      final created = await voiceEngine.createTts(
        _targetLang,
        speakerId: ttsVoiceId[_targetLang],
        speed: ttsSpeed,
      );
      
      if (!created) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model TTS belum diunduh. Buka Pengaturan > Model.')),
          );
        }
        return;
      }
      
      final ttsResult = await voiceEngine.generateTts(
        _translationResult,
        speed: ttsSpeed,
        pitch: ttsPitch,
      );
      
      if (ttsResult != null && mounted) {
        // Play audio using platform channel
        await _playAudio(ttsResult.audioData, ttsResult.sampleRate);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS gagal: $e')),
        );
      }
    }
  }

  Future<void> _playAudio(Uint8List audioData, int sampleRate) async {
    // TODO: Implement audio playback via MethodChannel or just_audio
    // For now, just show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio generated: ${audioData.length} bytes @ ${sampleRate}Hz')),
      );
    }
  }

  Future<void> _onStarResult() async {
    if (_translationResult.isEmpty || _inputController.text.isEmpty) return;
    
    try {
      final db = ref.read(appDatabaseProvider);
      // Check if already in history
      // For now, just add to phrasebook
      await db.addPhrase(
        category: 'custom',
        sourceText: _inputController.text,
        targetTextFormal: _translationResult,
        targetTextSlang: _translationResult,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
        isCustom: true,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disimpan ke Frasebook')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal simpan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terjemahan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: _translationResult.isNotEmpty ? _onCopyResult : null,
            tooltip: 'Salin hasil',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _translationResult.isNotEmpty ? () {
              // Share result
            } : null,
            tooltip: 'Bagikan',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Language selector row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: LanguageSelector(
                      selectedLang: _sourceLang,
                      onChanged: (lang) => setState(() => _sourceLang = lang),
                      label: 'Dari',
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _swapAnimationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _swapAnimationController.value * 3.14159,
                        child: IconButton(
                          icon: const Icon(Icons.swap_horiz, size: 28),
                          onPressed: _swapLanguages,
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                            foregroundColor: AppTheme.primaryTeal,
                          ),
                          tooltip: 'Tukar bahasa',
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: LanguageSelector(
                      selectedLang: _targetLang,
                      onChanged: (lang) => setState(() => _targetLang = lang),
                      label: 'Ke',
                      alignRight: true,
                    ),
                  ),
                ],
              ),
            ),

            // Formality toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: FormalityToggle(
                value: _formality,
                onChanged: _onFormalityChanged,
              ),
            ),

            // Input area
            Expanded(
              flex: 2,
              child: TranslationInput(
                controller: _inputController,
                sourceLang: _sourceLang,
                onVoiceTap: _onVoiceTap,
                onCameraTap: _onCameraTap,
                onPasteTap: _onPasteTap,
                onTextChanged: (text) {
                  // Debounced translation
                  _debounceTranslate(text);
                },
              ),
            ),

            // Output area
            Expanded(
              flex: 2,
              child: TranslationOutput(
                sourceLang: _sourceLang,
                targetLang: _targetLang,
                formality: _formality,
                translationResult: _translationResult,
                isTranslating: _isTranslating,
                onCopy: _onCopyResult,
                onSpeak: _onSpeakResult,
                onStar: _onStarResult,
              ),
            ),

            // Quick actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.mic),
                      label: const Text('Suara'),
                      onPressed: _onVoiceTap,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'),
                      onPressed: _onCameraTap,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.screenshot),
                      label: const Text('Layar'),
                      onPressed: () {
                        // TODO: Screenshot translate
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Debounce timer for translation
  int _debounceCounter = 0;
  Future<void> _debounceTranslate(String text) async {
    final currentCount = ++_debounceCounter;
    await Future.delayed(const Duration(milliseconds: 500));
    if (currentCount == _debounceCounter && mounted) {
      await _translateText(text);
    }
  }
}