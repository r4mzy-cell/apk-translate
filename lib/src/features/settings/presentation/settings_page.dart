import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/features/settings/presentation/model_manager_page.dart';
import 'package:translate_id/src/services/translation/translation_engine.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              trailing: const _ThemeSelector(),
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
              trailing: const _FormalitySelector(),
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
              trailing: const _TtsVoiceSelector(language: 'id'),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.record_voice_over_outlined, color: AppTheme.primaryTeal),
              title: 'Suara TTS Inggris',
              subtitle: 'Pilih suara',
              trailing: const _TtsVoiceSelector(language: 'en'),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.speed_outlined, color: AppTheme.primaryTeal),
              title: 'Kecepatan Bicara',
              subtitle: '0.5x - 2.0x',
              trailing: const _SpeedSlider(),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.tune_outlined, color: AppTheme.primaryTeal),
              title: 'Pitch',
              subtitle: '0.5 - 2.0',
              trailing: const _PitchSlider(),
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
              subtitle: 'Pilih folder (bisa SD card)',
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
              trailing: Switch(value: true, onChanged: (v) {}),
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
              trailing: const _AutoClearSelector(),
              onTap: () {},
            ),
            _SettingsDivider(),
            _SettingsTile(
              leading: Icon(Icons.cloud_off_outlined, color: AppTheme.primaryTeal),
              title: 'Mode Offline Ketat',
              subtitle: 'Blokir semua akses jaringan kecuali download model',
              trailing: Switch(value: false, onChanged: (v) {}),
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
              trailing: Switch(value: false, onChanged: (v) {}),
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
              subtitle: '1.0.0 (Build 1)',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
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

  void _showStoragePicker(BuildContext context) {
    // TODO: Implement storage picker
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pemilih folder...')));
  }

  void _exportData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mengekspor data...')));
  }

  void _importData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memilih file backup...')));
  }

  void _viewLogs(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membuka log...')));
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(context: context, applicationName: 'TranslateID', applicationVersion: '1.0.0');
  }

  void _shareApp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membuka berbagi LAN...')));
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menghapus semua data...')));
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
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Connect to theme provider
    return DropdownButton<ThemeMode>(
      value: ThemeMode.system,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: ThemeMode.system, child: Text('Mengikuti Sistem')),
        DropdownMenuItem(value: ThemeMode.light, child: Text('Terang')),
        DropdownMenuItem(value: ThemeMode.dark, child: Text('Gelap')),
      ],
      onChanged: (v) {},
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
  const _FormalitySelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButton<FormalityMode>(
      value: FormalityMode.formal,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: FormalityMode.formal, child: Text('Formal (Anda, tidak, apakah)')),
        DropdownMenuItem(value: FormalityMode.slang, child: Text('Tidak Formal (lu/gue, nggak, apa)')),
      ],
      onChanged: (v) {},
    );
  }
}

// TTS Voice Selector
class _TtsVoiceSelector extends StatelessWidget {
  final String language;

  const _TtsVoiceSelector({required this.language});

  @override
  Widget build(BuildContext context) {
    final voices = language == 'id'
        ? ['Wanita 1', 'Wanita 2', 'Pria 1', 'Pria 2', 'Anak', 'Lansia', 'Formal', 'Kasual', 'News', 'Story']
        : ['Wanita (US)', 'Pria (US)', 'Wanita (UK)', 'Pria (UK)'];

    return DropdownButton<String>(
      value: voices.first,
      underline: const SizedBox(),
      items: voices.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) {},
    );
  }
}

// Speed Slider
class _SpeedSlider extends StatelessWidget {
  const _SpeedSlider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Slider(
        value: 1.0,
        min: 0.5,
        max: 2.0,
        divisions: 15,
        label: '1.0x',
        onChanged: (v) {},
      ),
    );
  }
}

// Pitch Slider
class _PitchSlider extends StatelessWidget {
  const _PitchSlider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Slider(
        value: 1.0,
        min: 0.5,
        max: 2.0,
        divisions: 15,
        label: '1.0',
        onChanged: (v) {},
      ),
    );
  }
}

// Storage Path Selector
class _StoragePathSelector extends StatelessWidget {
  const _StoragePathSelector();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Internal Storage/TranslateID/models',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

// Auto Clear Selector
class _AutoClearSelector extends StatelessWidget {
  const _AutoClearSelector();

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: 'never',
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 'never', child: Text('Tidak pernah')),
        DropdownMenuItem(value: '7d', child: Text('7 hari')),
        DropdownMenuItem(value: '30d', child: Text('30 hari')),
        DropdownMenuItem(value: '90d', child: Text('90 hari')),
        DropdownMenuItem(value: '365d', child: Text('1 tahun')),
      ],
      onChanged: (v) {},
    );
  }
}
