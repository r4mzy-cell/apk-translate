import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'app_database.g.dart';

/// Translation history entry
@DataClassName('HistoryEntry')
class HistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceText => text().withLength(min: 1, max: 5000)();
  TextColumn get targetText => text().withLength(min: 1, max: 5000)();
  TextColumn get sourceLang => text().withLength(min: 2, max: 2)(); // 'en' or 'id'
  TextColumn get targetLang => text().withLength(min: 2, max: 2)();
  IntColumn get timestamp => integer()(); // milliseconds since epoch
  TextColumn get type => text().withLength(min: 1, max: 20)(); // 'text', 'voice', 'camera', 'screen', 'document'
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();
  TextColumn get context => text().nullable()(); // full sentence context for starred words
  TextColumn get tags => text().nullable()(); // comma-separated tags for starred entries
}

/// Starred/Favorite words
@DataClassName('StarredWord')
class StarredWords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceText => text().withLength(min: 1, max: 200)();
  TextColumn get targetText => text().withLength(min: 1, max: 200)();
  TextColumn get sourceLang => text().withLength(min: 2, max: 2)();
  TextColumn get targetLang => text().withLength(min: 2, max: 2)();
  TextColumn get context => text().nullable()();
  TextColumn get tags => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

/// Phrasebook entries
@DataClassName('PhrasebookEntry')
class PhrasebookEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text().withLength(min: 1, max: 50)(); // 'emergency', 'transport', 'food', 'shopping', 'work', 'slang'
  TextColumn get sourceText => text().withLength(min: 1, max: 500)();
  TextColumn get targetTextFormal => text().withLength(min: 1, max: 500)();
  TextColumn get targetTextSlang => text().withLength(min: 1, max: 500)();
  TextColumn get sourceLang => text().withLength(min: 2, max: 2)();
  TextColumn get targetLang => text().withLength(min: 2, max: 2)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))(); // user added vs built-in
}

/// Model metadata
@DataClassName('ModelInfoEntity')
class Models extends Table {
  TextColumn get id => text().withLength(min: 1, max: 100)(); // unique identifier
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get type => text().withLength(min: 1, max: 30)(); // 'stt', 'tts', 'translation', 'vad', 'langid'
  TextColumn get language => text().withLength(min: 2, max: 10)(); // 'en', 'id', 'multi'
  TextColumn get version => text().nullable()();
  IntColumn get sizeBytes => integer()();
  TextColumn get checksum => text().nullable()(); // SHA256
  TextColumn get localPath => text().nullable()();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  IntColumn get downloadedAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();
}

/// User preferences
@DataClassName('UserPreference')
class UserPreferences extends Table {
  TextColumn get key => text().withLength(min: 1, max: 100)();
  TextColumn get value => text().nullable()();
  TextColumn get valueType => text().withLength(min: 1, max: 20).withDefault(const Constant('string'))(); // 'string', 'int', 'bool', 'double', 'json'

  @override
  Set<Column> get primaryKey => {key};
}

/// Conversation sessions - TEMPORARILY DISABLED DUE TO DRIFT BUG
// @DataClassName('ConversationSession')
// class ConversationSessions extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   TextColumn get title => text().nullable()();
//   IntColumn get createdAt => integer()();
//   IntColumn get updatedAt => integer()();
//   TextColumn get languageA => text().withLength(min: 2, max: 2)(); // 'en' or 'id'
//   TextColumn get languageB => text().withLength(min: 2, max: 2)();
// }
//
// /// Conversation messages - TEMPORARILY DISABLED DUE TO DRIFT BUG
// @DataClassName('ConversationMessage')
// class ConversationMessages extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   IntColumn get sessionId => integer()();
//   TextColumn get text => text().withLength(min: 1, max: 2000)();
//   TextColumn get translatedText => text().withLength(min: 1, max: 2000)();
//   TextColumn get sourceLang => text().withLength(min: 2, max: 2)();
//   TextColumn get targetLang => text().withLength(min: 2, max: 2)();
//   TextColumn get speaker => text().withLength(min: 1, max: 20)(); // 'me', 'other', 'system'
//   IntColumn get timestamp => integer()();
//   BoolColumn get isVoice => boolean().withDefault(const Constant(false))();
// }

/// Document translation jobs
@DataClassName('DocumentJob')
class DocumentJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text().withLength(min: 1, max: 500)();
  TextColumn get filePath => text().withLength(min: 1, max: 1000)();
  TextColumn get fileType => text().withLength(min: 1, max: 20)(); // 'pdf', 'txt', 'docx'
  TextColumn get sourceLang => text().withLength(min: 2, max: 2)();
  TextColumn get targetLang => text().withLength(min: 2, max: 2)();
  TextColumn get status => text().withLength(min: 1, max: 20)(); // 'pending', 'processing', 'completed', 'failed'
  IntColumn get totalSegments => integer().withDefault(const Constant(0))();
  IntColumn get completedSegments => integer().withDefault(const Constant(0))();
  TextColumn get outputPath => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get completedAt => integer().nullable()();
}

@DriftDatabase(tables: [
  HistoryEntries,
  StarredWords,
  PhrasebookEntries,
  Models,
  UserPreferences,
  DocumentJobs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._(QueryExecutor executor) : super(executor);

  static AppDatabase open(String path) {
    return AppDatabase._(NativeDatabase.createInBackground(File(path)));
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _insertDefaultData();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations
      },
    );
  }

  static Future<void> _insertDefaultData() async {
    // Insert default phrasebook entries
    // This will be called on first run
  }

  // Preference helpers
  Future<bool> _getBoolPreference(String key, bool defaultValue) async {
    final row = await (select(userPreferences)..where((p) => p.key.equals(key))).getSingleOrNull();
    if (row == null || row.value == null) return defaultValue;
    return row.value == 'true';
  }

  Future<String> _getStringPreference(String key, String defaultValue) async {
    final row = await (select(userPreferences)..where((p) => p.key.equals(key))).getSingleOrNull();
    if (row == null || row.value == null) return defaultValue;
    return row.value!;
  }

  Future<double> _getDoublePreference(String key, double defaultValue) async {
    final row = await (select(userPreferences)..where((p) => p.key.equals(key))).getSingleOrNull();
    if (row == null || row.value == null) return defaultValue;
    return double.tryParse(row.value!) ?? defaultValue;
  }

  Future<void> _setPreference(String key, String value, String type) async {
    await into(userPreferences).insertOnConflictUpdate(
      UserPreferencesCompanion.insert(
        key: key,
        value: Value(value),
        valueType: Value(type),
      ),
    );
  }

  // Convenience getters for common preferences
  Future<String> getThemeMode() => _getStringPreference('theme_mode', 'system');
  Future<void> setThemeMode(String value) => _setPreference('theme_mode', value, 'string');

  // Deprecated: kept for migration
  @Deprecated('Use getThemeMode/setThemeMode')
  Future<bool> get isDarkMode => _getBoolPreference('theme_dark', false);
  @Deprecated('Use getThemeMode/setThemeMode')
  Future<void> setDarkMode(bool value) => _setPreference('theme_dark', value.toString(), 'bool');

  Future<String> get defaultFormality => _getStringPreference('formality', 'formal');
  Future<void> setDefaultFormality(String value) => _setPreference('formality', value, 'string');

  Future<String> get ttsVoiceId => _getStringPreference('tts_voice_id', 'id_female_0');
  Future<void> setTtsVoiceId(String value) => _setPreference('tts_voice_id', value, 'string');

  Future<double> get ttsSpeed => _getDoublePreference('tts_speed', 1.0);
  Future<void> setTtsSpeed(double value) => _setPreference('tts_speed', value.toString(), 'double');

  Future<double> get ttsPitch => _getDoublePreference('tts_pitch', 1.0);
  Future<void> setTtsPitch(double value) => _setPreference('tts_pitch', value.toString(), 'double');

  Future<bool> get downloadWifiOnly => _getBoolPreference('download_wifi_only', true);
  Future<void> setDownloadWifiOnly(bool value) => _setPreference('download_wifi_only', value.toString(), 'bool');

  Future<String> get autoClearHistory => _getStringPreference('auto_clear_history', 'never');
  Future<void> setAutoClearHistory(String value) => _setPreference('auto_clear_history', value, 'string');

  Future<bool> get strictOfflineMode => _getBoolPreference('strict_offline_mode', false);
  Future<void> setStrictOfflineMode(bool value) => _setPreference('strict_offline_mode', value.toString(), 'bool');

  Future<bool> get debugLoggingEnabled => _getBoolPreference('debug_logging', false);
  Future<void> setDebugLoggingEnabled(bool value) => _setPreference('debug_logging', value.toString(), 'bool');

  Future<String> get modelStoragePath => _getStringPreference('model_storage_path', '');
  Future<void> setModelStoragePath(String value) => _setPreference('model_storage_path', value, 'string');
}