import 'package:material_ui/material_ui.dart';

/// Formality mode for Indonesian translations
enum FormalityMode { formal, slang }

extension FormalityModeExt on FormalityMode {
  String get label {
    switch (this) {
      case FormalityMode.formal:
        return 'Formal';
      case FormalityMode.slang:
        return 'Tidak Formal';
    }
  }

  String get description {
    switch (this) {
      case FormalityMode.formal:
        return 'Anda, tidak, apakah, bagaimana';
      case FormalityMode.slang:
        return 'Lu/gue, nggak, apa, gimana';
    }
  }

  IconData get icon {
    switch (this) {
      case FormalityMode.formal:
        return Icons.business_outlined;
      case FormalityMode.slang:
        return Icons.chat_bubble_outline;
    }
  }
}
