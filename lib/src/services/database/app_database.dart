import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:translate_id/src/shared/enums/history_filter.dart';

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
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))(); // user starred
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _insertDefaultData();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add isFavorite, createdAt, updatedAt to phrasebook_entries
          await m.addColumn(phrasebookEntries, phrasebookEntries.isFavorite);
          await m.addColumn(phrasebookEntries, phrasebookEntries.createdAt);
          await m.addColumn(phrasebookEntries, phrasebookEntries.updatedAt);
        }
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

  // ============ PHRASEBOOK HELPERS ============
  Future<List<PhrasebookEntry>> getAllPhrases({String? category}) async {
    final query = select(phrasebookEntries)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    if (category != null) {
      query.where((t) => t.category.equals(category));
    }
    return query.get();
  }

  Future<List<PhrasebookEntry>> getFavoritePhrases() async {
    return (select(phrasebookEntries)..where((t) => t.isFavorite.equals(true))).get();
  }

  Future<int> addPhrase({
    required String category,
    required String sourceText,
    required String targetTextFormal,
    required String targetTextSlang,
    String sourceLang = 'en',
    String targetLang = 'id',
    int sortOrder = 0,
    bool isCustom = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return await into(phrasebookEntries).insert(
      PhrasebookEntriesCompanion.insert(
        category: category,
        sourceText: sourceText,
        targetTextFormal: targetTextFormal,
        targetTextSlang: targetTextSlang,
        sourceLang: sourceLang,
        targetLang: targetLang,
        sortOrder: sortOrder,
        isCustom: isCustom,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updatePhrase(int id, {
    String? category,
    String? sourceText,
    String? targetTextFormal,
    String? targetTextSlang,
    bool? isFavorite,
  }) async {
    final companion = PhrasebookEntriesCompanion(
      id: Value(id),
      category: category != null ? Value(category) : const Value.absent(),
      sourceText: sourceText != null ? Value(sourceText) : const Value.absent(),
      targetTextFormal: targetTextFormal != null ? Value(targetTextFormal) : const Value.absent(),
      targetTextSlang: targetTextSlang != null ? Value(targetTextSlang) : const Value.absent(),
      isFavorite: isFavorite != null ? Value(isFavorite) : const Value.absent(),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await update(phrasebookEntries).replace(companion);
  }

  Future<void> deletePhrase(int id) async {
    await (delete(phrasebookEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<void> togglePhraseFavorite(int id, bool isFavorite) async {
    await (update(phrasebookEntries)..where((t) => t.id.equals(id)))
        .write(PhrasebookEntriesCompanion(
      isFavorite: Value(isFavorite),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<void> insertDefaultPhrases() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaultPhrases = [
      // Emergency
      ('emergency', 'Help!', 'Tolong!', 'Tolong dong!', 'en', 'id', 0),
      ('emergency', 'Call the police!', 'Hubungi polisi!', 'Telpon polisi dong!', 'en', 'id', 1),
      ('emergency', 'I need a doctor', 'Saya butuh dokter', 'Gue butuh dokter nih', 'en', 'id', 2),
      ('emergency', 'Where is the hospital?', 'Di mana rumah sakitnya?', 'Rumah sakitnya di mana sih?', 'en', 'id', 3),
      ('emergency', 'I\'m lost', 'Saya tersesat', 'Gue kesasar nih', 'en', 'id', 4),
      // Transport
      ('transport', 'Where is the bus stop?', 'Di mana halte busnya?', 'Haltenya di mana ya?', 'en', 'id', 0),
      ('transport', 'How much is the fare?', 'Berapa ongkosnya?', 'Ongkosnya berapa sih?', 'en', 'id', 1),
      ('transport', 'I want to go to...', 'Saya mau ke...', 'Gue mau ke...', 'en', 'id', 2),
      ('transport', 'Does this go to...?', 'Apakah ini ke...?', 'Ini ke... nggak?', 'en', 'id', 3),
      ('transport', 'One ticket, please', 'Satu tiket, tolong', 'Satu tiket ya', 'en', 'id', 4),
      // Food
      ('food', 'I\'m hungry', 'Saya lapar', 'Gue lapar nih', 'en', 'id', 0),
      ('food', 'What do you recommend?', 'Apa rekomendasinya?', 'Recomend nya apa?', 'en', 'id', 1),
      ('food', 'No spicy, please', 'Tidak pedas, tolong', 'Nggak pedes ya', 'en', 'id', 2),
      ('food', 'The bill, please', 'Bonnya, tolong', 'Bon ya', 'en', 'id', 3),
      ('food', 'Delicious!', 'Enak sekali!', 'Enak banget!', 'en', 'id', 4),
      // Shopping
      ('shopping', 'How much is this?', 'Ini berapa harganya?', 'Ini berapa ya?', 'en', 'id', 0),
      ('shopping', 'Too expensive', 'Terlalu mahal', 'Mahal banget', 'en', 'id', 1),
      ('shopping', 'Can you lower the price?', 'Bisa ditawar?', 'Bisa nggak ditawar?', 'en', 'id', 2),
      ('shopping', 'I\'ll take it', 'Saya beli ini', 'Gue ambil ini', 'en', 'id', 3),
      ('shopping', 'Do you have...?', 'Apakah ada...?', 'Ada... nggak?', 'en', 'id', 4),
      // Work
      ('work', 'Good morning', 'Selamat pagi', 'Pagi', 'en', 'id', 0),
      ('work', 'See you tomorrow', 'Sampai jumpa besok', 'Dah jumpa besok', 'en', 'id', 1),
      ('work', 'I\'ll send the file', 'Saya kirim filenya', 'Gue kirim filenya ya', 'en', 'id', 2),
      ('work', 'Meeting at 2 PM', 'Rapat jam 2 siang', 'Meeting jam 2', 'en', 'id', 3),
      ('work', 'Thank you for your help', 'Terima kasih atas bantuannya', 'Makasih ya bantuannya', 'en', 'id', 4),
      // Slang
      ('slang', 'What\'s up?', 'Apa kabar?', 'Gimana kabarnya? / Apa kabar?', 'en', 'id', 0),
      ('slang', 'No way!', 'Tidak mungkin!', 'Nggak mungkin deh! / Emang nggak bisa!', 'en', 'id', 1),
      ('slang', 'Are you serious?', 'Apakah kamu serius?', 'Beneran? / Serius?', 'en', 'id', 2),
      ('slang', 'Whatever', 'Terserah', 'Bebas aja / Terserah lu', 'en', 'id', 3),
      ('slang', 'No problem', 'Tidak masalah', 'Nggak apa-apa / Enggak masala', 'en', 'id', 4),
    ];

    for (final p in defaultPhrases) {
      await into(phrasebookEntries).insertOnConflictUpdate(
        PhrasebookEntriesCompanion.insert(
          category: p.$1,
          sourceText: p.$2,
          targetTextFormal: p.$3,
          targetTextSlang: p.$4,
          sourceLang: p.$5,
          targetLang: p.$6,
          sortOrder: p.$7,
          isCustom: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  // ============ HISTORY HELPERS ============
  Future<List<HistoryEntry>> getAllHistory() async {
    return (select(historyEntries)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();
  }

  Stream<List<HistoryEntry>> watchHistory({HistoryFilter? filter}) {
    var query = select(historyEntries)..orderBy([(t) => OrderingTerm.desc(t.timestamp)]);
    if (filter != null && filter != HistoryFilter.all) {
      query = query.where((t) => t.type.equals(filter.name));
    }
    return query.watch();
  }

  Stream<List<HistoryEntry>> watchStarredHistory() {
    return (select(historyEntries)
          ..where((t) => t.isStarred.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  Future<HistoryEntry?> getHistoryEntry(int id) async {
    return (select(historyEntries)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> toggleHistoryStar(int id, bool isStarred) async {
    await (update(historyEntries)..where((t) => t.id.equals(id)))
        .write(HistoryEntriesCompanion(isStarred: Value(isStarred)));
  }

  Future<void> deleteHistoryEntry(int id) async {
    await (delete(historyEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearHistoryOlderThan(int millisecondsSinceEpoch) async {
    await (delete(historyEntries)..where((t) => t.timestamp.isSmallerThanValue(millisecondsSinceEpoch))).go();
  }

  Future<void> clearAllHistory() async {
    await delete(historyEntries).go();
  }

  Future<int> addHistory({
    required String sourceText,
    required String targetText,
    required String sourceLang,
    required String targetLang,
    String type = 'text',
  }) async {
    return await into(historyEntries).insert(
      HistoryEntriesCompanion.insert(
        sourceText: sourceText,
        targetText: targetText,
        sourceLang: sourceLang,
        targetLang: targetLang,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: type,
        isStarred: const Value(false),
      ),
    );
  }
}