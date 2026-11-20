import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:translate_id/src/services/database/app_database.dart';
import 'package:translate_id/src/services/translation/translation_engine.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase provider must be overridden in main.dart');
});

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.read(appDatabaseProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final AppDatabase _db;

  ThemeModeNotifier(this._db) : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final themeStr = await _db.getThemeMode();
    switch (themeStr) {
      case 'dark':
        state = ThemeMode.dark;
        break;
      case 'light':
        state = ThemeMode.light;
        break;
      case 'system':
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _db.setThemeMode(mode.name);
  }
}

/// Formality provider
final defaultFormalityProvider = StateNotifierProvider<FormalityNotifier, FormalityMode>((ref) {
  return FormalityNotifier(ref.read(appDatabaseProvider));
});

class FormalityNotifier extends StateNotifier<FormalityMode> {
  final AppDatabase _db;

  FormalityNotifier(this._db) : super(FormalityMode.formal) {
    _load();
  }

  Future<void> _load() async {
    final val = await _db.defaultFormality;
    state = val == 'slang' ? FormalityMode.slang : FormalityMode.formal;
  }

  Future<void> setFormality(FormalityMode mode) async {
    state = mode;
    await _db.setDefaultFormality(mode.name);
  }
}

/// TTS Voice ID provider (per language)
final ttsVoiceIdProvider = StateNotifierProvider<TtsVoiceIdNotifier, Map<String, String>>((ref) {
  return TtsVoiceIdNotifier(ref.read(appDatabaseProvider));
});

class TtsVoiceIdNotifier extends StateNotifier<Map<String, String>> {
  final AppDatabase _db;

  TtsVoiceIdNotifier(this._db) : super({'id': 'id_female_0', 'en': 'en_female_0'}) {
    _load();
  }

  Future<void> _load() async {
    state = {
      'id': await _db.ttsVoiceId,
      'en': 'en_female_0',
    };
  }

  Future<void> setVoiceId(String language, String voiceId) async {
    state = {...state, language: voiceId};
    if (language == 'id') {
      await _db.setTtsVoiceId(voiceId);
    }
  }
}

/// TTS Speed provider
final ttsSpeedProvider = StateNotifierProvider<TtsSpeedNotifier, double>((ref) {
  return TtsSpeedNotifier(ref.read(appDatabaseProvider));
});

class TtsSpeedNotifier extends StateNotifier<double> {
  final AppDatabase _db;

  TtsSpeedNotifier(this._db) : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    state = await _db.ttsSpeed;
  }

  Future<void> setSpeed(double speed) async {
    state = speed.clamp(0.5, 2.0);
    await _db.setTtsSpeed(state);
  }
}

/// TTS Pitch provider
final ttsPitchProvider = StateNotifierProvider<TtsPitchNotifier, double>((ref) {
  return TtsPitchNotifier(ref.read(appDatabaseProvider));
});

class TtsPitchNotifier extends StateNotifier<double> {
  final AppDatabase _db;

  TtsPitchNotifier(this._db) : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    state = await _db.ttsPitch;
  }

  Future<void> setPitch(double pitch) async {
    state = pitch.clamp(0.5, 2.0);
    await _db.setTtsPitch(state);
  }
}

/// Download WiFi only provider
final downloadWifiOnlyProvider = StateNotifierProvider<DownloadWifiOnlyNotifier, bool>((ref) {
  return DownloadWifiOnlyNotifier(ref.read(appDatabaseProvider));
});

class DownloadWifiOnlyNotifier extends StateNotifier<bool> {
  final AppDatabase _db;

  DownloadWifiOnlyNotifier(this._db) : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await _db.downloadWifiOnly;
  }

  Future<void> setWifiOnly(bool value) async {
    state = value;
    await _db.setDownloadWifiOnly(value);
  }
}

/// Auto clear history provider
final autoClearHistoryProvider = StateNotifierProvider<AutoClearHistoryNotifier, String>((ref) {
  return AutoClearHistoryNotifier(ref.read(appDatabaseProvider));
});

class AutoClearHistoryNotifier extends StateNotifier<String> {
  final AppDatabase _db;

  AutoClearHistoryNotifier(this._db) : super('never') {
    _load();
  }

  Future<void> _load() async {
    state = await _db.autoClearHistory;
  }

  Future<void> setAutoClear(String value) async {
    state = value;
    await _db.setAutoClearHistory(value);
  }
}

/// Strict offline mode provider
final strictOfflineModeProvider = StateNotifierProvider<StrictOfflineModeNotifier, bool>((ref) {
  return StrictOfflineModeNotifier(ref.read(appDatabaseProvider));
});

class StrictOfflineModeNotifier extends StateNotifier<bool> {
  final AppDatabase _db;

  StrictOfflineModeNotifier(this._db) : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await _db.strictOfflineMode;
  }

  Future<void> setStrictOffline(bool value) async {
    state = value;
    await _db.setStrictOfflineMode(value);
  }
}

/// Debug logging provider
final debugLoggingProvider = StateNotifierProvider<DebugLoggingNotifier, bool>((ref) {
  return DebugLoggingNotifier(ref.read(appDatabaseProvider));
});

class DebugLoggingNotifier extends StateNotifier<bool> {
  final AppDatabase _db;

  DebugLoggingNotifier(this._db) : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await _db.debugLoggingEnabled;
  }

  Future<void> setDebugLogging(bool value) async {
    state = value;
    await _db.setDebugLoggingEnabled(value);
  }
}

/// Model storage path provider
final modelStoragePathProvider = StateNotifierProvider<ModelStoragePathNotifier, String>((ref) {
  return ModelStoragePathNotifier(ref.read(appDatabaseProvider));
});

class ModelStoragePathNotifier extends StateNotifier<String> {
  final AppDatabase _db;

  ModelStoragePathNotifier(this._db) : super('') {
    _load();
  }

  Future<void> _load() async {
    state = await _db.modelStoragePath;
  }

  Future<void> setPath(String path) async {
    state = path;
    await _db.setModelStoragePath(path);
  }
}

/// App version provider
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (Build ${info.buildNumber})';
  } catch (_) {
    return '1.0.0 (Build 1)';
  }
});