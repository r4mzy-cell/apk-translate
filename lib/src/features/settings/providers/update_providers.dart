import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translate_id/src/services/update/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

final updateProgressProvider = StateNotifierProvider<UpdateProgressNotifier, UpdateProgress>((ref) {
  return UpdateProgressNotifier(ref.read(updateServiceProvider));
});

class UpdateProgressNotifier extends StateNotifier<UpdateProgress> {
  final UpdateService _service;

  UpdateProgressNotifier(this._service) : super(UpdateProgress.idle());

  Future<void> checkForUpdate() async {
    state = UpdateProgress.checking();
    try {
      final info = await _service.checkForUpdate();
      if (info != null && info.isNewer) {
        state = UpdateProgress.available(info);
      } else {
        state = UpdateProgress.upToDate();
      }
    } catch (e) {
      state = UpdateProgress.error('Gagal cek pembaruan: $e');
    }
  }

  Future<void> downloadAndInstall(UpdateInfo info) async {
    try {
      state = UpdateProgress.downloading(0, info.sizeBytes);
      
      final file = await _service.downloadApk(info, (downloaded, total) {
        state = UpdateProgress.downloading(downloaded, total);
      });

      if (file == null) {
        state = UpdateProgress.error('Download gagal');
        return;
      }

      state = UpdateProgress.installing();
      final success = await _service.installApk(file);
      
      if (!success) {
        state = UpdateProgress.error('Instalasi gagal');
      }
      // If success, app will be replaced; no state update needed
    } catch (e) {
      state = UpdateProgress.error('Error: $e');
    }
  }

  void reset() {
    state = UpdateProgress.idle();
  }
}