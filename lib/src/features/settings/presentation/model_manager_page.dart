import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/services/model/model_manager.dart';
import 'package:translate_id/src/models/model_info.dart';

class ModelManagerPage extends ConsumerStatefulWidget {
  const ModelManagerPage({super.key});

  @override
  ConsumerState<ModelManagerPage> createState() => _ModelManagerPageState();
}

class _ModelManagerPageState extends ConsumerState<ModelManagerPage> {
  String _filter = 'all'; // all, downloaded, not_downloaded

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelsAsync = ref.watch(modelManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Model'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('Semua')),
              PopupMenuItem(value: 'downloaded', child: Text('Sudah Diunduh')),
              PopupMenuItem(value: 'not_downloaded', child: Text('Belum Diunduh')),
            ],
          ),
        ],
      ),
      body: modelsAsync.when(
        data: (models) {
          final filtered = models.where((m) {
            if (_filter == 'downloaded') return m.isDownloaded;
            if (_filter == 'not_downloaded') return !m.isDownloaded;
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return _EmptyState(filter: _filter);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final model = filtered[index];
              return _ModelCard(model: model);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String message;
    IconData icon;

    switch (filter) {
      case 'downloaded':
        message = 'Belum ada model yang diunduh';
        icon = Icons.download_outlined;
        break;
      case 'not_downloaded':
        message = 'Semua model sudah diunduh!';
        icon = Icons.check_circle_outline;
        break;
      default:
        message = 'Tidak ada model';
        icon = Icons.inbox_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const Gap(16),
          Text(message, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ModelCard extends ConsumerWidget {
  final ModelInfo model;

  const _ModelCard({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final manager = ref.read(modelManagerProvider.notifier);
    final progress = ref.watch(modelManagerProvider.select((v) => v.valueOrNull))
        ?.firstWhere((m) => m.id == model.id, orElse: () => model);
    final downloadProgress = ref.watch(modelManagerProvider.notifier).getProgress(model.id);

    final isDownloading = downloadProgress?.status == DownloadStatus.downloading ||
        downloadProgress?.status == DownloadStatus.connecting ||
        downloadProgress?.status == DownloadStatus.verifying;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _TypeIcon(type: model.type),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text('${model.typeDisplayName} • ${model.language.toUpperCase()}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StatusChip(model: model, isDownloading: isDownloading),
              ],
            ),

            const Gap(12),

            // Size info
            Row(
              children: [
                Icon(Icons.storage_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const Gap(4),
                Text(model.sizeFormatted, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                if (model.isDownloaded && model.localPath != null)
                  Text('Tersimpan', style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.primaryTeal)),
              ],
            ),

            // Progress bar
            if (isDownloading && downloadProgress != null) ...[
              const Gap(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(downloadProgress.progressFormatted, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.primaryTeal)),
                      Text('${downloadProgress.downloadedFormatted} / ${downloadProgress.totalFormatted} • ${downloadProgress.speedFormatted}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const Gap(4),
                  LinearProgressIndicator(
                    value: downloadProgress.progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primaryTeal),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ],

            // Error message
            if (downloadProgress?.status == DownloadStatus.failed && downloadProgress!.errorMessage != null) ...[
              const Gap(8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const Gap(8),
                    Expanded(child: Text(downloadProgress.errorMessage!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.red))),
                  ],
                ),
              ),
            ],

            // Actions
            const Gap(12),
            Row(
              children: [
                if (!model.isDownloaded) ...[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Unduh'),
                      onPressed: () => _downloadWithWifiCheck(context, manager),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                    ),
                  ),
                ] else ...[
                  if (model.type != ModelType.vad && model.type != ModelType.langId) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(model.isActive ? Icons.check_circle : Icons.radio_button_unchecked),
                        label: Text(model.isActive ? 'Aktif' : 'Aktifkan'),
                        onPressed: () => manager.setActiveModel(model.id, !model.isActive),
                      ),
                    ),
                    const Gap(8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus'),
                      onPressed: () => _confirmDelete(context, manager),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red)),
                    ),
                  ),
                ],
                if (isDownloading) ...[
                  const Gap(8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.pause),
                    label: const Text('Jeda'),
                    onPressed: () => manager.pauseDownload(model.id),
                  ),
                  const Gap(8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text('Batal'),
                    onPressed: () => manager.cancelDownload(model.id),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadWithWifiCheck(BuildContext context, ModelManager manager) async {
    // TODO: Check WiFi connectivity
    try {
      await manager.downloadModel(model.id, wifiOnly: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${model.name} selesai diunduh')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _confirmDelete(BuildContext context, ModelManager manager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Model?'),
        content: Text('Model "${model.name}" (${model.sizeFormatted}) akan dihapus. Anda perlu mengunduh ulang nanti jika dibutuhkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              manager.deleteModel(model.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final ModelType type;

  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    IconData icon;
    Color color;

    switch (type) {
      case ModelType.stt:
        icon = Icons.mic;
        color = Colors.blue;
        break;
      case ModelType.tts:
        icon = Icons.record_voice_over;
        color = Colors.green;
        break;
      case ModelType.translation:
        icon = Icons.translate;
        color = AppTheme.primaryTeal;
        break;
      case ModelType.vad:
        icon = Icons.hearing;
        color = Colors.orange;
        break;
      case ModelType.langId:
        icon = Icons.language;
        color = Colors.purple;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ModelInfo model;
  final bool isDownloading;

  const _StatusChip({required this.model, required this.isDownloading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isDownloading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
            const Gap(6),
            Text('Mengunduh...', style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange[700], fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (!model.isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Belum Diunduh', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    if (model.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryTeal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: AppTheme.primaryTeal),
            const Gap(4),
            Text('Aktif', style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.primaryTeal, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_done, size: 12, color: Colors.green),
          const Gap(4),
          Text('Tersedia', style: theme.textTheme.labelSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
