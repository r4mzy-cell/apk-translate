import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/features/settings/presentation/model_manager_page.dart';
import 'package:translate_id/src/features/settings/providers/settings_providers.dart';
import 'package:translate_id/src/features/settings/providers/update_providers.dart';
import 'package:translate_id/src/services/update/update_service.dart';
import 'package:translate_id/src/services/translation/translation_engine.dart';
import 'package:translate_id/src/shared/enums/formality_mode.dart';
import 'package:translate_id/src/shared/utils/app_logger.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final formality = ref.watch(defaultFormalityProvider);
    final ttsVoiceId = ref.watch(ttsVoiceIdProvider);
    final ttsSpeed = ref.watch(ttsSpeedProvider);
    final ttsPitch = ref.watch(ttsPitchProvider);
    final downloadWifiOnly = ref.watch(downloadWifiOnlyProvider);
    final autoClearHistory = ref.watch(autoClearHistoryProvider);
    final strictOffline = ref.watch(strictOfflineModeProvider);
    final debugLogging = ref.watch(debugLoggingProvider);
    final modelStoragePath = ref.watch(modelStoragePathProvider);
    final versionAsync = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _SectionHeader(title: 'Tampilan'),
          _SettingsCard(children: [
            _SettingsTile(
              leading: Icon(Icons.palette_outlined, color: AppTheme.primaryTeal),
              title: 'Tema',
              subtitle: 'Pilih mode tampilan',
              trailing: _ThemeSelector(current: themeMode),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.language_outlined, color: AppTheme.primaryTeal),
              title: 'Bahasa Aplikasi',
              subtitle: 'Bahasa antarmuka (default: mengikuti sistem)',
              trailing: const _LanguageSelector(),
              onTap: () {},
            ),
          ]),

          const Gap(24),

          // Translation Section
          _SectionHeader(title: 'Terjemahan'),
          _SettingsCard(children: [
            _SettingsTile(
              leading: Icon(Icons.translate_outlined, color: AppTheme.primaryTeal),
              title: 'Formalitas Default',
              subtitle: 'Pilih gaya terjemahan default',
              trailing: _FormalitySelector(current: formality),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.auto_awesome_outlined, color: AppTheme.primaryTeal),
              title: 'Deteksi Bahasa Otomatis',
              subtitle: 'Otomatis mendeteksi EN/ID dari input',
              trailing: Switch(value: true, onChanged: (v) {}),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.save_outlined, color: AppTheme.primaryTeal),
              title: 'Simpan Otomatis ke Riwayat',
              subtitle: 'Setiap terjemahan disimpan ke riwayat',
              trailing: Switch(value: true, onChanged: (v) {}),
              onTap: () {},
            ),
          ]),

          const Gap(24),

          // Voice Section
          _SectionHeader(title: 'Suara (TTS)'),
          _SettingsCard(children: [
            _SettingsTile(
              leading: Icon(Icons.record_voice_over_outlined, color: AppTheme.primaryTeal),
              title: 'Suara TTS Indonesia',
              subtitle: 'Pilih suara (10 speaker tersedia)',
              trailing: _TtsVoiceSelector(language: 'id', current: ttsVoiceId['id'] ?? 'id_female_0'),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.record_voice_over_outlined, color: AppTheme.primaryTeal),
              title: 'Suara TTS Inggris',
              subtitle: 'Pilih suara',
              trailing: _TtsVoiceSelector(language: 'en', current: ttsVoiceId['en'] ?? 'en_female_0'),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.speed_outlined, color: AppTheme.primaryTeal),
              title: 'Kecepatan Bicara',
              subtitle: '${ttsSpeed.toStringAsFixed(1)}x',
              trailing: _SpeedSlider(current: ttsSpeed),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.tune_outlined, color: AppTheme.primaryTeal),
              title: 'Pitch',
              subtitle: ttsPitch.toStringAsFixed(1),
              trailing: _PitchSlider(current: ttsPitch),
              onTap: () {},
            ),
          ]),

          const Gap(24),

          // Model Management Section
          _SectionHeader(title: 'Manajemen Model'),
          _SettingsCard(children: [
            _SettingsTile(
              leading: Icon(Icons.folder_outlined, color: AppTheme.primaryTeal),
              title: 'Lokasi Penyimpanan Model',
              subtitle: modelStoragePath.isEmpty ? 'Default: Internal/TranslateID/models' : modelStoragePath,
              trailing: const _StoragePathSelector(),
              onTap: () => _showStoragePicker(context),
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.download_outlined, color: AppTheme.primaryTeal),
              title: 'Kelola Model',
              subtitle: 'Download, hapus, aktifkan model',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelManagerPage())),
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.wifi_outlined, color: AppTheme.primaryTeal),
              title: 'Download Hanya Via WiFi',
              subtitle: 'Hindari penggunaan data seluler',
              trailing: Switch(value: downloadWifiOnly, onChanged: (v) => ref.read(downloadWifiOnlyProvider.notifier).setWifiOnly(v)),
              onTap: () {},
            ),
          ]),

          const Gap(24),

          // Data Section
          _SectionHeader(title: 'Data & Privasi'),
          _SettingsCard(children: [
            _SettingsTile(
              leading: Icon(Icons.history_outlined, color: AppTheme.primaryTeal),
              title: 'Hapus Riwayat Otomatis',
              subtitle: 'Hapus riwayat lebih lama dari...',
              trailing: _AutoClearSelector(current: autoClearHistory),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.cloud_off_outlined, color: AppTheme.primaryTeal),
              title: 'Mode Offline Ketat',
              subtitle: 'Blokir semua akses jaringan kecuali download model',
              trailing: Switch(value: strictOffline, onChanged: (v) => ref.read(strictOfflineModeProvider.notifier).setStrictOffline(v)),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.backup_outlined, color: AppTheme.primaryTeal),
              title: 'Ekspor Semua Data',
              subtitle: 'Backup riwayat, favorit, frasa ke file',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportData(context),
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.restore_outlined, color: AppTheme.primaryTeal),
              title: 'Impor Data',
              subtitle: 'Pulihkan dari backup',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _importData(context),
            ),
          ]),

          const Gap(24),

          // Advanced Section
          _SectionHeader(title: 'Lanjutan'),
          _SettingsCard(children: [
            _SettingsTile(
              leading: Icon(Icons.developer_mode_outlined, color: AppTheme.primaryTeal),
              title: 'Debug Logging',
              subtitle: 'Aktifkan log detail untuk troubleshooting',
              trailing: Switch(value: debugLogging, onChanged: (v) => ref.read(debugLoggingProvider.notifier).setDebugLogging(v)),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.bug_report_outlined, color: AppTheme.primaryTeal),
              title: 'Lihat Log',
              subtitle: 'Buka file log aplikasi',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _viewLogs(context),
            ),
          ]),

          const Gap(24),

          // About Section
          _SectionHeader(title: 'Tentang'),
          _SettingsCard(children: [
            _SettingsTile(
              leading: Icon(Icons.info_outline, color: AppTheme.primaryTeal),
              title: 'Versi Aplikasi',
              subtitle: versionAsync.when(
                data: (v) => v,
                loading: () => 'Memuat...',
                error: (_, _) => '1.0.0 (Build 1)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.system_update_outlined, color: AppTheme.primaryTeal),
              title: 'Cek Pembaruan',
              subtitle: _buildUpdateSubtitle(ref),
              trailing: _buildUpdateTrailing(ref, context),
              onTap: () => _handleUpdateTap(ref, context),
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.code_outlined, color: AppTheme.primaryTeal),
              title: 'Open Source Licenses',
              subtitle: 'Lisensi dependensi yang digunakan',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLicenses(context),
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.share_outlined, color: AppTheme.primaryTeal),
              title: 'Bagikan Aplikasi ke Teman',
              subtitle: 'QR Code + LAN transfer',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _shareApp(context),
            ),
          ]),

          const Gap(32),

          // Danger Zone
          _SectionHeader(title: 'Zona Bahaya', icon: Icons.warning_amber_outlined, iconColor: Colors.red),
          _SettingsCard(children: [
            _SettingsTile(
              leading: Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: 'Hapus Semua Data Aplikasi',
              subtitle: 'Riwayat, favorit, frasa, model, pengaturan - SEMUA',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmResetAll(context),
            ),
          ]),

          const Gap(32),
        ],
      ),
    );
  }

  String _buildUpdateSubtitle(WidgetRef ref) {
    final update = ref.watch(updateProgressProvider);
    switch (update.status) {
      case UpdateStatus.idle:
        return 'Ketuk untuk memeriksa versi terbaru';
      case UpdateStatus.checking:
        return 'Memeriksa pembaruan...';
      case UpdateStatus.upToDate:
        return 'Aplikasi sudah versi terbaru';
      case UpdateStatus.updateAvailable:
        return 'Versi ${update.info!.version} tersedia (${update.info!.formattedSize})';
      case UpdateStatus.downloading:
        final pct = (update.progress * 100).toStringAsFixed(0);
        return 'Mengunduh... $pct%';
      case UpdateStatus.installing:
        return 'Membuka installer...';
      case UpdateStatus.error:
        return update.message ?? 'Gagal';
    }
  }

  Widget _buildUpdateTrailing(WidgetRef ref, BuildContext context) {
    final update = ref.watch(updateProgressProvider);
    switch (update.status) {
      case UpdateStatus.checking:
      case UpdateStatus.downloading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UpdateStatus.updateAvailable:
        return FilledButton(
          onPressed: () => _handleUpdateTap(ref, context),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 32),
          ),
          child: const Text('Perbarui'),
        );
      case UpdateStatus.installing:
        return const Icon(Icons.downloading, color: AppTheme.primaryTeal);
      default:
        return const Icon(Icons.chevron_right);
    }
  }

  Future<void> _handleUpdateTap(WidgetRef ref, BuildContext context) async {
    final notifier = ref.read(updateProgressProvider.notifier);
    final current = ref.read(updateProgressProvider);

    if (current.status == UpdateStatus.updateAvailable && current.info != null) {
      final info = current.info!;
      // Confirm before download
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Perbarui Aplikasi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versi ${info.version} (${info.formattedSize})'),
              const Gap(8),
              if (info.releaseNotes.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    child: Text(info.releaseNotes, style: Theme.of(ctx).textTheme.bodySmall),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unduh & Pasang')),
          ],
        ),
      );
      if (ok == true) {
        await notifier.downloadAndInstall(info);
      }
      return;
    }

    await notifier.checkForUpdate();
    final result = ref.read(updateProgressProvider);
    if (result.status == UpdateStatus.upToDate && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aplikasi sudah versi terbaru')),
      );
    } else if (result.status == UpdateStatus.error && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Gagal cek pembaruan')),
      );
    } else if (result.status == UpdateStatus.updateAvailable && context.mounted) {
      await _handleUpdateTap(ref, context);
    }
  }

  Future<void> _showStoragePicker(BuildContext context) async {
    try {
      // file_picker 13.x+ uses static method
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Pilih Folder Model (Download/Sideload)',
      );
      
      if (result != null && context.mounted) {
        await ref.read(modelStoragePathProvider.notifier).setPath(result);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lokasi disetel: $result')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('Storage not available');
      final file = File('${dir.path}/translateid_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      // TODO: Implement actual export (history, favorites, phrases)
      await file.writeAsString('{"exported": true, "timestamp": ${DateTime.now().millisecondsSinceEpoch}}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Diekspor ke: ${file.path}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ekspor: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    // TODO: Implement file picker for import
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur impor belum tersedia')));
    }
  }

  Future<void> _viewLogs(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // AppLogger writes to /logs, not /app_flutter/logs
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folder log tidak ditemukan')));
        }
        return;
      }
      final files = await logDir.list().toList();
      if (files.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada file log')));
        }
        return;
      }
      final latest = files
          .whereType<File>()
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (latest.isEmpty) return;
      final content = await latest.first.readAsString();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Log: ${latest.first.uri.pathSegments.last}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(child: SelectableText(content)),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal baca log: $e')));
      }
    }
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(context: context, applicationName: 'TranslateID', applicationVersion: '1.0.0');
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      await Share.share('Coba TranslateID - Translator offline EN↔ID\nhttps://github.com/r4mzy-cell/apk-translate');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal bagikan: $e')));
      }
    }
  }

  void _confirmResetAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(Icons.warning, color: Colors.red), const Gap(8), const Text('PERINGATAN')]),
        content: const Text(
          'Ini akan menghapus SEMUA data:\n'
          '• Riwayat terjemahan\n'
          '• Kata favorit\n'
          '• Frasa kustom\n'
          '• Model yang didownload (~640MB)\n'
          '• Semua pengaturan\n\n'
          'Tindakan ini TIDAK DAPAT DIBATALKAN.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menghapus semua data...')));
              }
              // TODO: Implement actual reset
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('HAPUS SEMUA'),
          ),
        ],
      ),
    );
  }
}

// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;

  const _SectionHeader({required this.title, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor ?? AppTheme.primaryTeal),
            const Gap(8),
          ],
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Settings Card Wrapper
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(children: children),
    );
  }
}

// Settings Tile
class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: leading,
      title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// Divider
class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: theme.dividerColor, thickness: 1),
    );
  }
}

// Theme Selector
class _ThemeSelector extends ConsumerWidget {
  final ThemeMode current;

  const _ThemeSelector({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButton<ThemeMode>(
      value: current,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: ThemeMode.system, child: Text('Mengikuti Sistem')),
        DropdownMenuItem(value: ThemeMode.light, child: Text('Terang')),
        DropdownMenuItem(value: ThemeMode.dark, child: Text('Gelap')),
      ],
      onChanged: (v) => ref.read(themeModeProvider.notifier).setThemeMode(v!),
    );
  }
}

// Language Selector
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: 'system',
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 'system', child: Text('Mengikuti Sistem')),
        DropdownMenuItem(value: 'id', child: Text('Indonesia')),
        DropdownMenuItem(value: 'en', child: Text('English')),
      ],
      onChanged: (v) {},
    );
  }
}

// Formality Selector
class _FormalitySelector extends ConsumerWidget {
  final FormalityMode current;

  const _FormalitySelector({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButton<FormalityMode>(
      value: current,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: FormalityMode.formal, child: Text('Formal (Anda, tidak, apakah)')),
        DropdownMenuItem(value: FormalityMode.slang, child: Text('Tidak Formal (lu/gue, nggak, apa)')),
      ],
      onChanged: (v) => ref.read(defaultFormalityProvider.notifier).setFormality(v!),
    );
  }
}

// TTS Voice Selector
class _TtsVoiceSelector extends ConsumerWidget {
  final String language;
  final String current;

  const _TtsVoiceSelector({required this.language, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voices = language == 'id'
        ? ['id_female_0', 'id_female_1', 'id_male_0', 'id_male_1', 'id_child', 'id_elderly', 'id_formal', 'id_casual', 'id_news', 'id_story']
        : ['en_female_0', 'en_male_0', 'en_female_1', 'en_male_1'];

    final labels = language == 'id'
        ? ['Wanita 1', 'Wanita 2', 'Pria 1', 'Pria 2', 'Anak', 'Lansia', 'Formal', 'Kasual', 'News', 'Story']
        : ['Wanita (US)', 'Pria (US)', 'Wanita (UK)', 'Pria (UK)'];

    return DropdownButton<String>(
      value: current,
      underline: const SizedBox(),
      items: List.generate(voices.length, (i) => DropdownMenuItem(value: voices[i], child: Text(labels[i]))),
      onChanged: (v) => ref.read(ttsVoiceIdProvider.notifier).setVoiceId(language, v!),
    );
  }
}

// Speed Slider
class _SpeedSlider extends ConsumerWidget {
  final double current;

  const _SpeedSlider({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 120,
      child: Slider(
        value: current,
        min: 0.5,
        max: 2.0,
        divisions: 15,
        label: '${current.toStringAsFixed(1)}x',
        onChanged: (v) => ref.read(ttsSpeedProvider.notifier).setSpeed(v),
      ),
    );
  }
}

// Pitch Slider
class _PitchSlider extends ConsumerWidget {
  final double current;

  const _PitchSlider({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 120,
      child: Slider(
        value: current,
        min: 0.5,
        max: 2.0,
        divisions: 15,
        label: current.toStringAsFixed(1),
        onChanged: (v) => ref.read(ttsPitchProvider.notifier).setPitch(v),
      ),
    );
  }
}

// Storage Path Selector
class _StoragePathSelector extends StatelessWidget {
  const _StoragePathSelector();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.chevron_right);
  }
}

// Auto Clear Selector
class _AutoClearSelector extends ConsumerWidget {
  final String current;

  const _AutoClearSelector({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButton<String>(
      value: current,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 'never', child: Text('Tidak pernah')),
        DropdownMenuItem(value: '7d', child: Text('7 hari')),
        DropdownMenuItem(value: '30d', child: Text('30 hari')),
        DropdownMenuItem(value: '90d', child: Text('90 hari')),
        DropdownMenuItem(value: '365d', child: Text('1 tahun')),
      ],
      onChanged: (v) => ref.read(autoClearHistoryProvider.notifier).setAutoClear(v!),
    );
  }
}