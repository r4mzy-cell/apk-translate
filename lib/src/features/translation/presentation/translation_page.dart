import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/shared/widgets/language_selector.dart';
import 'package:translate_id/src/shared/widgets/translation_input.dart';
import 'package:translate_id/src/shared/widgets/translation_output.dart';
import 'package:translate_id/src/shared/enums/formality_mode.dart';
import 'package:translate_id/src/shared/widgets/formality_toggle.dart';
import 'package:translate_id/src/shared/widgets/voice_button.dart';

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

  @override
  void initState() {
    super.initState();
    _swapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _swapAnimationController.dispose();
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
    });
  }

  void _onFormalityChanged(FormalityMode mode) {
    setState(() => _formality = mode);
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
            onPressed: () {
              // Copy result
            },
            tooltip: 'Salin hasil',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share result
            },
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
                onVoiceTap: () {
                  // TODO: Start voice input
                },
                onCameraTap: () {
                  // TODO: Open camera OCR
                },
                onTextChanged: (text) {
                  // Trigger translation
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
                onCopy: () {},
                onSpeak: () {},
                onStar: () {},
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
                      onPressed: () {
                        // TODO: Voice translation mode
                      },
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'),
                      onPressed: () {
                        // TODO: Camera OCR
                      },
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
}
