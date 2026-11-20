import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translate_id/src/core/di/service_locator.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/features/home/presentation/home_page.dart';
import 'package:translate_id/src/services/database/app_database.dart';
import 'package:translate_id/src/services/model/model_manager.dart';
import 'package:translate_id/src/services/permissions/permission_service.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';
import 'package:translate_id/src/features/settings/providers/settings_providers.dart';
import 'package:get_it/get_it.dart';

/// Background service entry point — runs in separate isolate
/// Keeps the process alive (foreground service) while downloads run.
@pragma('vm:entry-point')
void backgroundServiceOnStart(ServiceInstance service) {
  debugPrint('Background download service started');
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

Future<void> _configureBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundServiceOnStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'translateid_download',
      initialNotificationTitle: 'Translator ID',
      initialNotificationContent: 'Mengunduh model...',
      foregroundServiceNotificationId: 8888,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

Future<void> _requestPermissionsOnFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final hasRequested = prefs.getBool('permissions_requested') ?? false;
  if (!hasRequested) {
    await PermissionService().requestAllPermissions();
    await prefs.setBool('permissions_requested', true);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure background/foreground service for downloads
  await _configureBackgroundService();
  
  // Request permissions on first launch
  await _requestPermissionsOnFirstLaunch();
  
  try {
    await setupServiceLocator();
    await AppLogger.init();
  } catch (e, stack) {
    // Log to console (visible in logcat)
    print('Startup error: $e');
    print(stack);
    // Re-throw to show error screen
    rethrow;
  }

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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id'), Locale('en')],
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
