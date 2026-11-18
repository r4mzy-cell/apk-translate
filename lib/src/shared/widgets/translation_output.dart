import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/shared/enums/formality_mode.dart';

class TranslationOutput extends StatelessWidget {
  final String sourceLang;
  final String targetLang;
  final FormalityMode formality;
  final VoidCallback onCopy;
  final VoidCallback onSpeak;
  final VoidCallback onStar;

  const TranslationOutput({
    super.key,
    required this.sourceLang,
    required this.targetLang,
    required this.formality,
    required this.onCopy,
    required this.onSpeak,
    required this.onStar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.05),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    targetLang.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.primaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Gap(8),
                Text(
                  'Hasil Terjemahan',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (formality == FormalityMode.slang)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Tidak Formal',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Translation result
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(8),
                    SelectableText(
                      'Hasil terjemahan akan muncul di sini...',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const Gap(16),
                  ],
                ),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.content_copy_outlined, color: AppTheme.primaryTeal),
                  onPressed: onCopy,
                  tooltip: 'Salin',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: Icon(Icons.volume_up_outlined, color: AppTheme.primaryTeal),
                  onPressed: onSpeak,
                  tooltip: 'Dengarkan',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: Icon(Icons.star_border_outlined, color: AppTheme.primaryTeal),
                  onPressed: onStar,
                  tooltip: 'Simpan ke favorit',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.share_outlined, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () {
                    // Share
                  },
                  tooltip: 'Bagikan',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}