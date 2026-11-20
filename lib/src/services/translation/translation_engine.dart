import 'dart:async';
import 'package:flutter/services.dart';
import 'package:translate_id/src/services/model/model_manager.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';

/// Translation result
class TranslationResult {
  final String text;
  final String sourceLang;
  final String targetLang;
  final Duration latency;
  final bool fromCache;

  const TranslationResult({
    required this.text,
    required this.sourceLang,
    required this.targetLang,
    required this.latency,
    this.fromCache = false,
  });

  factory TranslationResult.fromMap(Map<dynamic, dynamic> map) {
    return TranslationResult(
      text: map['text'] as String? ?? '',
      sourceLang: map['sourceLang'] as String? ?? '',
      targetLang: map['targetLang'] as String? ?? '',
      latency: Duration.zero,
      fromCache: map['fromCache'] as bool? ?? false,
    );
  }
}

/// Translation formality mode
enum FormalityMode { formal, slang }

/// Translation engine using ONNX Runtime + Opus-MT via MethodChannel
class TranslationEngine {
  final ModelManager _modelManager;
  static const _channel = MethodChannel('com.translateid/native');
  
  bool _initialized = false;
  String _translatorId = 'translator_default';

  TranslationEngine(this._modelManager);

  /// Initialize ONNX Runtime library
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final status = await _channel.invokeMethod('translatorStatus');
      _initialized = status['loaded'] == true;
      if (_initialized) {
        AppLogger.info('TranslationEngine initialized via ONNX Runtime native bridge');
      } else {
        AppLogger.warning('ONNX Runtime library not loaded');
      }
    } catch (e) {
      AppLogger.error('Failed to initialize TranslationEngine', e);
      rethrow;
    }
  }

  /// Create translator for a language pair
  Future<bool> createTranslator(String sourceLang, String targetLang) async {
    if (!_initialized) await initialize();
    
    final modelId = sourceLang == 'en' ? 'ctranslate-en-id' : 'ctranslate-id-en';
    final model = _modelManager.currentModels?.firstWhere(
      (m) => m.id == modelId,
      orElse: () => throw Exception('Translation model not found: $modelId'),
    );
    
    if (model == null || !model.isDownloaded || model.localPath == null) {
      AppLogger.error('Translation model not downloaded: $modelId');
      return false;
    }

    final modelPath = model.localPath!;
    _translatorId = 'translator_${sourceLang}_$targetLang';
    
    try {
      final result = await _channel.invokeMethod('initTranslator', {
        'id': _translatorId,
        'modelPath': modelPath,
      });
      AppLogger.info('Created translator $sourceLang->$targetLang: $result');
      return result as bool? ?? false;
    } catch (e) {
      AppLogger.error('Failed to create translator', e);
      return false;
    }
  }

  /// Translate text from source to target language
  Future<TranslationResult> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
    FormalityMode formality = FormalityMode.formal,
  }) async {
    if (!_initialized) await initialize();

    final stopwatch = Stopwatch()..start();

    // Ensure translator exists for this language pair
    final expectedId = 'translator_${sourceLang}_$targetLang';
    if (_translatorId != expectedId) {
      await createTranslator(sourceLang, targetLang);
    }

    // Apply formality preprocessing
    String processedText = _applyFormalityPreprocess(text, sourceLang, formality);

    // Call native translation
    String translated;
    try {
      translated = await _translateNative(processedText, sourceLang, targetLang);
    } catch (e) {
      AppLogger.error('Translation failed', e);
      translated = text; // fallback
    }

    // Apply formality postprocess
    final result = _applyFormalityPostprocess(translated, targetLang, formality);

    stopwatch.stop();

    return TranslationResult(
      text: result,
      sourceLang: sourceLang,
      targetLang: targetLang,
      latency: stopwatch.elapsed,
    );
  }

  /// Translate multiple segments (for documents)
  Future<List<TranslationResult>> translateBatch({
    required List<String> texts,
    required String sourceLang,
    required String targetLang,
    FormalityMode formality = FormalityMode.formal,
  }) async {
    final results = <TranslationResult>[];
    for (final text in texts) {
      results.add(await translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
        formality: formality,
      ));
    }
    return results;
  }

  /// Native translation via platform channel
  Future<String> _translateNative(String text, String sourceLang, String targetLang) async {
    try {
      final result = await _channel.invokeMethod('translate', {
        'id': _translatorId,
        'text': text,
        'beamSize': 4,
      });
      return result as String? ?? text;
    } catch (e) {
      AppLogger.error('Native translation failed', e);
      return text;
    }
  }

  /// Detect language of text (simple heuristic for EN/ID)
  String detectLanguage(String text) {
    final indonesianWords = {
      'dan', 'yang', 'untuk', 'dengan', 'dari', 'ke', 'di', 'pada', 'adalah',
      'ini', 'itu', 'saya', 'kamu', 'dia', 'kami', 'kita', 'mereka', 'akan',
      'sudah', 'belum', 'bisa', 'tidak', 'ada', 'bukan', 'juga', 'atau',
      'jika', 'maka', 'karena', 'sebagai', 'seperti', 'lebih', 'kurang',
      'sama', 'lain', 'baru', 'lama', 'besar', 'kecil', 'panjang', 'pendek',
      'tinggi', 'rendah', 'cepat', 'lambat', 'baik', 'buruk', 'benar', 'salah'
    };
    final words = text.toLowerCase().split(RegExp(r'\W+'));
    int indonesianCount = 0;
    for (final w in words) {
      if (indonesianWords.contains(w)) indonesianCount++;
    }
    return indonesianCount > words.length * 0.15 ? 'id' : 'en';
  }

  /// Slang is applied to the translated output only. Rewriting the source would
  /// feed the MT model non-standard text, which lowers translation quality.
  String _applyFormalityPreprocess(String text, String lang, FormalityMode mode) {
    return text;
  }

  String _applyFormalityPostprocess(String text, String lang, FormalityMode mode) {
    if (mode == FormalityMode.formal) return text;

    // For slang mode: convert formal Indonesian to informal
    if (lang == 'id' && mode == FormalityMode.slang) {
      String result = text;
      final replacements = {
        'Anda': 'lu',
        'saya': 'gue',
        'kami': 'kita',
        'tidak': 'nggak',
        'bukan': 'bukan',
        'apakah': 'apa',
        'bagaimana': 'gimana',
        'mengapa': 'kenapa',
        'terima kasih': 'makasih',
        'mohon maaf': 'maap',
        'sudah': 'udah',
        'belum': 'belum',
        'sedang': 'lagi',
        'akan': 'bakal',
        'ingin': 'mau',
        'perlu': 'perlu',
        'harus': 'harus',
        'bisa': 'bisa',
        'boleh': 'boleh',
        'baik': 'oke',
        'bagus': 'bagus',
        'jelek': 'jelek',
      };
      for (final entry in replacements.entries) {
        result = result.replaceAllMapped(RegExp(r'\b${entry.key}\b', caseSensitive: false), (m) => entry.value);
      }
      // Add casual particles randomly
      if (result.endsWith('.')) {
        final particles = [' deh', ' dong', ' sih', ' ya', ' lah', ' kok'];
        result = result.substring(0, result.length - 1) + particles[DateTime.now().millisecond % particles.length] + '.';
      }
      return result;
    }

    // For slang mode: convert formal English to informal
    if (lang == 'en' && mode == FormalityMode.slang) {
      String result = text;
      final replacements = {
        'you': 'u',
        'what': 'wut',
        'going to': 'gonna',
        'want to': 'wanna',
        'have to': 'hafta',
        'got to': 'gotta',
        'let me': 'lemme',
        'give me': 'gimme',
        'i am': 'im',
        'i will': 'ill',
        'do not': 'dont',
        'cannot': 'cant',
        'what is': 'whats',
        'it is': 'its',
        'that is': 'thats',
        'there is': 'theres',
        'how is': 'hows',
        'where is': 'wheres',
        'who is': 'whos',
        'when is': 'whens',
        'why is': 'whys',
        'because': 'cuz',
        'about': 'bout',
        'probably': 'prolly',
        'something': 'somethin',
        'nothing': 'nothin',
        'anything': 'anythin',
        'everything': 'everythin',
        'yes': 'yeah',
        'no': 'nah',
        'maybe': 'mayb',
        'sure': 'shure',
        'really': 'rly',
        'very': 'v',
        'so': 's0',
        'too': '2',
        'also': 'als0',
        'but': 'bt',
        'and': 'n',
        'or': 'r',
        'please': 'pls',
        'thanks': 'thx',
        'thank you': 'thx',
        'okay': 'ok',
        'oh my god': 'omg',
        'oh my gosh': 'omg',
        'by the way': 'btw',
        'for your information': 'fyi',
        'in my opinion': 'imo',
        'to be honest': 'tbh',
        'i don\'t know': 'idk',
        'i don\'t care': 'idc',
        'i guess': 'iguess',
        'i think': 'ithink',
        'i know': 'iknow',
        'i see': 'isee',
        'let\'s': 'lets',
        'what\'s': 'whats',
        'that\'s': 'thats',
        'it\'s': 'its',
        'there\'s': 'theres',
        'here\'s': 'heres',
        'how\'s': 'hows',
        'where\'s': 'wheres',
        'who\'s': 'whos',
        'when\'s': 'whens',
        'why\'s': 'whys',
      };
      // Longer phrases first to avoid partial replacements
      final sortedKeys = replacements.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
      for (final key in sortedKeys) {
        result = result.replaceAllMapped(RegExp(r'\b${RegExp.escape(key)}\b', caseSensitive: false), (m) => replacements[key]!);
      }
      // -ing -> -in suffix
      result = result.replaceAllMapped(RegExp(r'\b(\w+)ing\b'), (m) => '${m.group(1)}in');
      // Add casual particles randomly
      if (result.endsWith('.')) {
        final particles = [' lol', ' tbh', ' ngl', ' fr', ' smh', ' no cap', ' btw', ' imo', ' fyi'];
        result = result.substring(0, result.length - 1) + particles[DateTime.now().millisecond % particles.length] + '.';
      }
      return result;
    }
    return text;
  }

  void dispose() {
    // Cleanup
  }
}
