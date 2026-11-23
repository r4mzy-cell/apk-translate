import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translate_id/src/features/translation/presentation/translation_page.dart';
import 'package:translate_id/src/features/conversation/presentation/conversation_page.dart';
import 'package:translate_id/src/features/phrasebook/presentation/phrasebook_page.dart';
import 'package:translate_id/src/features/history/presentation/history_page.dart';
import 'package:translate_id/src/features/settings/presentation/settings_page.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/features/translation/providers/translation_providers.dart';
import 'package:translate_id/src/services/model/model_manager.dart';
import 'package:translate_id/src/features/settings/providers/update_providers.dart';
import 'package:translate_id/src/services/update/update_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = const [
    TranslationPage(),
    ConversationPage(),
    PhrasebookPage(),
    HistoryPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Engines + model scan are wired in main.dart before runApp.
    // Re-trigger scan here so a fresh sideload is detected when app resumes.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final found = await ref.read(modelManagerProvider.notifier).scanLocalModels();
        if (found.isNotEmpty) debugPrint('Auto-scan found models: $found');
      } catch (e) {
        debugPrint('Auto-scan failed: $e');
      }
    });

    // Auto-check for app updates (once per session, delay to not block UI)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      
      // Check if we already checked this session
      final prefs = await ref.read(updateProgressProvider.notifier).checkForUpdate();
      final update = ref.read(updateProgressProvider);
      
      if (update.status == UpdateStatus.updateAvailable && update.info != null && mounted) {
        await _showUpdateDialog(update.info!);
      }
    });
  }

  Future<void> _showUpdateDialog(UpdateInfo info) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pembaruan Tersedia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versi ${info.version} (${info.formattedSize}) sudah tersedia.'),
            const Gap(12),
            if (info.releaseNotes.isNotEmpty)
              SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  child: Text(info.releaseNotes, style: Theme.of(ctx).textTheme.bodySmall),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unduh & Pasang Sekarang'),
          ),
        ],
      ),
    );
    
    if (ok == true && mounted) {
      await ref.read(updateProgressProvider.notifier).downloadAndInstall(info);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          height: 72,
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          indicatorColor: AppTheme.primaryTeal.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          animationDuration: const Duration(milliseconds: 300),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.translate_outlined),
              selectedIcon: Icon(Icons.translate),
              label: 'Terjemah',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Percakapan',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Frasebook',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Riwayat',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}
