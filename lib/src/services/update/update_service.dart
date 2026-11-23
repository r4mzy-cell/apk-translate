import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';

/// GitHub repository for releases
const String _repoOwner = 'r4mzy-cell';
const String _repoName = 'apk-translate';
const String _githubApiUrl = 'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

/// ABI mapping: device ABI -> GitHub asset filename pattern
const Map<String, String> _abiAssetMap = {
  'arm64-v8a': 'app-arm64-v8a-release.apk',
  'armeabi-v7a': 'app-armeabi-v7a-release.apk',
  'x86_64': 'app-x86_64-release.apk',
  // universal fallback (if not split)
  'universal': 'app-universal-release.apk',
};

class UpdateInfo {
  final String version;
  final String buildNumber;
  final String releaseNotes;
  final String downloadUrl;
  final String assetName;
  final int sizeBytes;
  final DateTime publishedAt;
  final bool isNewer;

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.assetName,
    required this.sizeBytes,
    required this.publishedAt,
    required this.isNewer,
  });

  factory UpdateInfo.fromGitHubRelease(
    Map<String, dynamic> release,
    String currentVersion,
    String currentBuild,
  ) {
    final tagName = release['tag_name'] as String? ?? '';
    final version = tagName.replaceFirst('v', '');
    final buildNumber = release['target_commitish'] as String? ?? '';
    final notes = release['body'] as String? ?? 'No release notes.';
    final publishedAtStr = release['published_at'] as String?;
    final publishedAt = publishedAtStr != null ? DateTime.parse(publishedAtStr) : DateTime.now();

    final assets = (release['assets'] as List<dynamic>? ?? []);
    String downloadUrl = '';
    String assetName = '';
    int sizeBytes = 0;

    // Detect device ABI
    final abi = _getDeviceAbi();
    final targetAsset = _abiAssetMap[abi] ?? _abiAssetMap['universal']!;

    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name == targetAsset || name.endsWith('-release.apk')) {
        downloadUrl = asset['browser_download_url'] as String? ?? '';
        assetName = name;
        sizeBytes = (asset['size'] as int? ?? 0);
        break;
      }
    }

    // Fallback: first .apk asset
    if (downloadUrl.isEmpty) {
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? '';
          assetName = name;
          sizeBytes = (asset['size'] as int? ?? 0);
          break;
        }
      }
    }

    final isNewer = _compareVersions(version, currentVersion) > 0 ||
        (_compareVersions(version, currentVersion) == 0 && _compareVersions(buildNumber, currentBuild) > 0);

    return UpdateInfo(
      version: version,
      buildNumber: buildNumber,
      releaseNotes: notes,
      downloadUrl: downloadUrl,
      assetName: assetName,
      sizeBytes: sizeBytes,
      publishedAt: publishedAt,
      isNewer: isNewer,
    );
  }

  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map(int.tryParse).whereType<int>().toList();
    final pb = b.split('.').map(int.tryParse).whereType<int>().toList();
    for (int i = 0; i < 3; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  static String _getDeviceAbi() {
    if (Platform.isAndroid) {
      // Flutter's Platform.environment doesn't expose ABI directly.
      // Fallback: most modern devices are arm64-v8a.
      // Could use a native channel for exact ABI, but arm64-v8a covers >95%.
      return 'arm64-v8a';
    }
    return 'universal';
  }

  String get formattedSize {
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  final Dio _dio = Dio();

  UpdateService() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(minutes: 10)
      ..followRedirects = true;
  }

  /// Check for updates on GitHub
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = packageInfo.buildNumber;

      AppLogger.info('Checking for updates... current: $currentVersion+$currentBuild');

      final response = await _dio.get(_githubApiUrl, options: Options(
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'TranslateID-App',
        },
      ));

      if (response.statusCode != 200 || response.data == null) {
        AppLogger.warning('GitHub API returned ${response.statusCode}');
        return null;
      }

      final updateInfo = UpdateInfo.fromGitHubRelease(response.data, currentVersion, currentBuild);
      
      if (updateInfo.isNewer) {
        AppLogger.info('Update available: ${updateInfo.version}+${updateInfo.buildNumber} (${updateInfo.formattedSize})');
        return updateInfo;
      } else {
        AppLogger.info('App is up to date');
        return null;
      }
    } on DioException catch (e) {
      AppLogger.error('Update check failed: ${e.message}');
      return null;
    } catch (e, stack) {
      AppLogger.error('Update check error', e, stack);
      return null;
    }
  }

  /// Download APK with progress callback
  Future<File?> downloadApk(UpdateInfo info, void Function(int, int)? onProgress) async {
    if (info.downloadUrl.isEmpty) {
      AppLogger.error('No download URL for update');
      return null;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${info.assetName}');

    try {
      if (await file.exists()) await file.delete();

      AppLogger.info('Downloading update: ${info.assetName} (${info.formattedSize})');
      
      await _dio.download(
        info.downloadUrl,
        file.path,
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total);
        },
        options: Options(
          headers: {'Accept': 'application/octet-stream'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      AppLogger.info('Download complete: ${file.path}');
      return file;
    } on DioException catch (e) {
      AppLogger.error('Download failed: ${e.message}');
      return null;
    } catch (e, stack) {
      AppLogger.error('Download error', e, stack);
      return null;
    }
  }

  /// Install APK using open_filex (handles FileProvider on Android 7+)
  Future<bool> installApk(File apkFile) async {
    try {
      AppLogger.info('Installing APK: ${apkFile.path}');
      final result = await OpenFilex.open(apkFile.path);
      
      if (result.type == ResultType.done) {
        AppLogger.info('APK install intent launched');
        return true;
      } else {
        AppLogger.error('Install failed: ${result.message}');
        return false;
      }
    } catch (e, stack) {
      AppLogger.error('Install error', e, stack);
      return false;
    }
  }

  /// Full update flow: check → download → install
  Future<bool> performUpdate(void Function(int, int)? onProgress) async {
    final info = await checkForUpdate();
    if (info == null || !info.isNewer) return false;

    final file = await downloadApk(info, onProgress);
    if (file == null) return false;

    return await installApk(file);
  }
}

enum UpdateStatus { idle, checking, updateAvailable, downloading, installing, error, upToDate }

class UpdateProgress {
  final UpdateStatus status;
  final String? message;
  final int downloaded;
  final int total;
  final UpdateInfo? info;

  const UpdateProgress({
    required this.status,
    this.message,
    this.downloaded = 0,
    this.total = 0,
    this.info,
  });

  double get progress => total > 0 ? downloaded / total : 0.0;

  factory UpdateProgress.idle() => const UpdateProgress(status: UpdateStatus.idle);
  factory UpdateProgress.checking() => const UpdateProgress(status: UpdateStatus.checking);
  factory UpdateProgress.available(UpdateInfo info) => UpdateProgress(status: UpdateStatus.updateAvailable, info: info);
  factory UpdateProgress.downloading(int d, int t) => UpdateProgress(status: UpdateStatus.downloading, downloaded: d, total: t);
  factory UpdateProgress.installing() => const UpdateProgress(status: UpdateStatus.installing);
  factory UpdateProgress.upToDate() => const UpdateProgress(status: UpdateStatus.upToDate);
  factory UpdateProgress.error(String msg) => UpdateProgress(status: UpdateStatus.error, message: msg);
}