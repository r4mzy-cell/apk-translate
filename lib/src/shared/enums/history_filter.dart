/// History filter types for translation history
enum HistoryFilter { all, text, voice, camera, screen, document }

extension HistoryFilterExt on HistoryFilter {
  String get label {
    switch (this) {
      case HistoryFilter.all:
        return 'Semua';
      case HistoryFilter.text:
        return 'Teks';
      case HistoryFilter.voice:
        return 'Suara';
      case HistoryFilter.camera:
        return 'Kamera';
      case HistoryFilter.screen:
        return 'Layar';
      case HistoryFilter.document:
        return 'Dokumen';
    }
  }
}