import 'package:permission_handler/permission_handler.dart';

/// Service to manage runtime permissions
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  static const List<Permission> _requiredPermissions = [
    Permission.storage,
    Permission.manageExternalStorage,
    Permission.microphone,
    Permission.camera,
  ];

  /// Request all required permissions on first launch
  Future<void> requestAllPermissions() async {
    final statuses = await _requiredPermissions.request();
    
    for (final entry in statuses.entries) {
      if (!entry.value.isGranted) {
        // Log denied permissions but don't block
        print('Permission ${entry.key} not granted: ${entry.value}');
      }
    }
  }

  /// Check if all critical permissions are granted
  Future<bool> hasCriticalPermissions() async {
    for (final perm in [Permission.storage, Permission.manageExternalStorage, Permission.microphone]) {
      final status = await perm.status;
      if (!status.isGranted) return false;
    }
    return true;
  }

  /// Request specific permission
  Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }

  /// Open app settings for manual permission grant
  Future<void> openSettings() async {
    await openAppSettings();
  }
}