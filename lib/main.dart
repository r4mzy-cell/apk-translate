import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translate_id/src/core/di/service_locator.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/features/home/presentation/home_page.dart';
import 'package:translate_id/src/services/database/app_database.dart';
import 'package:translate_id/src/services/model/model_manager.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';
import 'package:get_it/get_it.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  await AppLogger.init();

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => getIt<AppDatabase>()),
    ],
  );

  runApp(UncontrolledProviderScope(
    container: container,
    child: const TranslateIdApp(),
  ));
}

class TranslateIdApp extends ConsumerWidget {
  const TranslateIdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'TranslateID',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: const [],
      supportedLocales: const [Locale('id'), Locale('en')],
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
