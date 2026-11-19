import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:translate_id/src/services/database/app_database.dart';
import 'package:translate_id/src/services/model/model_manager.dart';
import 'package:translate_id/src/services/translation/translation_engine.dart';
import 'package:translate_id/src/services/voice/voice_engine.dart';
import 'package:translate_id/src/services/ocr/ocr_engine.dart';
import 'package:translate_id/src/services/overlay/overlay_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Database
  final appDocDir = await getApplicationDocumentsDirectory().timeout(const Duration(seconds: 10));
  final dbPath = p.join(appDocDir.path, 'translate_id.sqlite');
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase.open(dbPath));

  // Core Services
  getIt.registerLazySingleton<ModelManager>(() => ModelManager());
  getIt.registerLazySingleton<TranslationEngine>(() => TranslationEngine(getIt<ModelManager>()));
  getIt.registerLazySingleton<VoiceEngine>(() => VoiceEngine(getIt<ModelManager>()));
  getIt.registerLazySingleton<OcrEngine>(() => OcrEngine());
  getIt.registerLazySingleton<OverlayService>(() => OverlayService());
}