import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';

class LanguageSelector extends StatelessWidget {
  final String selectedLang;
  final ValueChanged<String> onChanged;
  final String label;
  final bool alignRight;

  const LanguageSelector({
    super.key,
    required this.selectedLang,
    required this.onChanged,
    required this.label,
    this.alignRight = false,
  });

  static const Map<String, String> _langNames = {
    'en': 'English',
    'id': 'Indonesia',
  };

  static const Map<String, String> _langFlags = {
    'en': '🇺🇸',
    'id': '🇮🇩',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedLang,
        isExpanded: true,
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        dropdownColor: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: AppTheme.primaryTeal,
        ),
        items: _langNames.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(_langFlags[entry.key]!, style: const TextStyle(fontSize: 20)),
                const Gap(8),
                Text(entry.value),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        selectedItemBuilder: (context) {
          return _langNames.entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(_langFlags[entry.key]!, style: const TextStyle(fontSize: 18)),
                const Gap(6),
                Text(entry.value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              ],
            );
          }).toList();
        },
      ),
    );
  }
}
