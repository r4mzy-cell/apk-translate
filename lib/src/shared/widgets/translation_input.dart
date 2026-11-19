import 'package:material_ui/material_ui.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';

class TranslationInput extends StatelessWidget {
  final TextEditingController controller;
  final String sourceLang;
  final VoidCallback onVoiceTap;
  final VoidCallback onCameraTap;
  final ValueChanged<String> onTextChanged;

  const TranslationInput({
    super.key,
    required this.controller,
    required this.sourceLang,
    required this.onVoiceTap,
    required this.onCameraTap,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.keyboard_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const Gap(8),
                Text(
                  'Masukkan teks',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${controller.text.length}/5000',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Text field
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: controller,
                maxLines: null,
                maxLength: 5000,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                decoration: InputDecoration(
                  hintText: sourceLang == 'id' ? 'Ketik teks Indonesia di sini...' : 'Type English text here...',
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    height: 1.5,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: onTextChanged,
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.mic_none_outlined, color: AppTheme.primaryTeal),
                  onPressed: onVoiceTap,
                  tooltip: 'Input suara',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: Icon(Icons.camera_alt_outlined, color: AppTheme.primaryTeal),
                  onPressed: onCameraTap,
                  tooltip: 'Kamera OCR',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: Icon(Icons.content_paste_outlined, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () {
                    // Paste from clipboard
                  },
                  tooltip: 'Tempel dari clipboard',
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => controller.clear(),
                  tooltip: 'Hapus',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
