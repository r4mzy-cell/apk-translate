import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/shared/enums/formality_mode.dart';

class FormalityToggle extends StatelessWidget {
  final FormalityMode value;
  final ValueChanged<FormalityMode> onChanged;

  const FormalityToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: FormalityMode.values.map((mode) {
          final isSelected = value == mode;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.all(4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(mode),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryTeal : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mode.icon,
                          size: 20,
                          color: isSelected
                              ? (theme.brightness == Brightness.dark ? AppTheme.primaryDark : Colors.white)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const Gap(4),
                        Text(
                          mode.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? (theme.brightness == Brightness.dark ? AppTheme.primaryDark : Colors.white)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          mode.description,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? (theme.brightness == Brightness.dark ? AppTheme.primaryDark.withOpacity(0.8) : Colors.white.withOpacity(0.8))
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}