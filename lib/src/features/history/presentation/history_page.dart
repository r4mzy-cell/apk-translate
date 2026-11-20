import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/services/database/app_database.dart';
import 'package:translate_id/src/shared/enums/history_filter.dart';
import 'package:translate_id/src/features/settings/providers/settings_providers.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  HistoryFilter _filter = HistoryFilter.all;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} dipilih')
            : const Text('Riwayat'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
              )
            : null,
        actions: [
          if (!_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showSearchDialog(context),
            ),
            PopupMenuButton<HistoryFilter>(
              icon: const Icon(Icons.filter_list),
              onSelected: (v) => setState(() => _filter = v),
              itemBuilder: (context) => HistoryFilter.values.map((f) => PopupMenuItem(
                value: f,
                child: Text(f.label),
              )).toList(),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) => _handleMenuAction(v),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'export_json', child: Text('Ekspor JSON')),
                const PopupMenuItem(value: 'export_csv', child: Text('Ekspor CSV')),
                const PopupMenuItem(value: 'clear_all', child: Text('Hapus Semua')),
              ],
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.star_outline),
              onPressed: _toggleStarSelected,
              tooltip: 'Favorit/Batal favorit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected,
              tooltip: 'Hapus',
            ),
          ],
        ],
        bottom: _selectionMode ? null : PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: theme.textTheme.labelMedium,
              indicatorColor: AppTheme.primaryTeal,
              indicatorWeight: 3,
              labelColor: AppTheme.primaryTeal,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Semua'),
                Tab(text: 'Favorit'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HistoryListView(
            filter: _filter,
            searchQuery: _searchQuery,
            starredOnly: false,
            selectionMode: _selectionMode,
            selectedIds: _selectedIds,
            onItemTap: _onItemTap,
            onItemLongPress: _onItemLongPress,
            onSelectionChanged: _onSelectionChanged,
          ),
          _HistoryListView(
            filter: _filter,
            searchQuery: _searchQuery,
            starredOnly: true,
            selectionMode: _selectionMode,
            selectedIds: _selectedIds,
            onItemTap: _onItemTap,
            onItemLongPress: _onItemLongPress,
            onSelectionChanged: _onSelectionChanged,
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final controller = TextEditingController(text: _searchQuery);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cari Riwayat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Masukkan kata kunci...'),
          onSubmitted: (v) {
            setState(() => _searchQuery = v);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              setState(() => _searchQuery = controller.text);
              Navigator.pop(context);
            },
            child: const Text('Cari'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    final db = ref.read(appDatabaseProvider);
    switch (action) {
      case 'export_json':
        _exportHistory(db, 'json');
        break;
      case 'export_csv':
        _exportHistory(db, 'csv');
        break;
      case 'clear_all':
        _showClearAllDialog(db);
        break;
    }
  }

  Future<void> _exportHistory(AppDatabase db, String format) async {
    try {
      final entries = await db.getAllHistory();
      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riwayat kosong')));
        return;
      }
      // TODO: Implement actual export
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ekspor $format belum diimplementasikan')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ekspor: $e')));
    }
  }

  void _showClearAllDialog(AppDatabase db) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              await db.clearAllHistory();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua riwayat dihapus')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

  void _onItemTap(int id, HistoryEntry entry) {
    if (_selectionMode) {
      _toggleSelection(id);
    } else {
      _showDetailDialog(entry);
    }
  }

  void _onItemLongPress(int id) {
    if (!_selectionMode) {
      setState(() {
        _selectionMode = true;
        _selectedIds.add(id);
      });
    }
  }

  void _onSelectionChanged(Set<int> ids) {
    setState(() => _selectedIds
      ..clear()
      ..addAll(ids));
    if (_selectedIds.isEmpty) _selectionMode = false;
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _toggleStarSelected() {
    final db = ref.read(appDatabaseProvider);
    for (final id in _selectedIds) {
      final entry = db.getHistoryEntry(id);
      if (entry != null) {
        db.toggleHistoryStar(id, !entry.isStarred);
      }
    }
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorit diperbarui')));
  }

  void _deleteSelected() {
    final db = ref.read(appDatabaseProvider);
    for (final id in _selectedIds) {
      db.deleteHistoryEntry(id);
    }
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selectedIds.length} item dihapus')));
  }

  void _showDetailDialog(HistoryEntry entry) {
    final db = ref.read(appDatabaseProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.sourceText.length > 50 ? '${entry.sourceText.substring(0, 50)}...' : entry.sourceText),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Asli', text: entry.sourceText, lang: entry.sourceLang),
              const Gap(12),
              _DetailRow(label: 'Terjemahan', text: entry.targetText, lang: entry.targetLang),
              const Gap(12),
              _DetailRow(label: 'Waktu', text: DateFormat('dd MMM yyyy, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(entry.timestamp))),
              const Gap(12),
              _DetailRow(label: 'Tipe', text: entry.type),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          IconButton(
            icon: Icon(entry.isStarred ? Icons.star : Icons.star_border, color: AppTheme.primaryTeal),
            onPressed: () async {
              await db.toggleHistoryStar(entry.id, !entry.isStarred);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              await db.deleteHistoryEntry(entry.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryListView extends ConsumerWidget {
  final HistoryFilter filter;
  final String searchQuery;
  final bool starredOnly;
  final bool selectionMode;
  final Set<int> selectedIds;
  final Function(int, HistoryEntry) onItemTap;
  final Function(int) onItemLongPress;
  final Function(Set<int>) onSelectionChanged;

  const _HistoryListView({
    required this.filter,
    required this.searchQuery,
    required this.starredOnly,
    required this.selectionMode,
    required this.selectedIds,
    required this.onItemTap,
    required this.onItemLongPress,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final theme = Theme.of(context);

    final historyStream = starredOnly
        ? db.watchStarredHistory()
        : db.watchHistory(filter: filter);

    return StreamBuilder<List<HistoryEntry>>(
      stream: historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var entries = snapshot.data ?? [];

        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          entries = entries.where((e) =>
            e.sourceText.toLowerCase().contains(q) ||
            e.targetText.toLowerCase().contains(q)
          ).toList();
        }

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
                const Gap(16),
                Text(
                  searchQuery.isEmpty ? 'Riwayat kosong' : 'Tidak ditemukan',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isSelected = selectedIds.contains(entry.id);
            return _HistoryCard(
              entry: entry,
              isSelected: isSelected,
              selectionMode: selectionMode,
              onTap: () => onItemTap(entry.id, entry),
              onLongPress: () => onItemLongPress(entry.id),
              onSelectionChanged: (selected) {
                final newSet = Set<int>.from(selectedIds);
                if (selected) newSet.add(entry.id); else newSet.remove(entry.id);
                onSelectionChanged(newSet);
              },
            );
          },
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(bool) onSelectionChanged;

  const _HistoryCard({
    required this.entry,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectionChanged,
  });

  static const Map<String, IconData> _typeIcons = {
    'text': Icons.text_fields,
    'voice': Icons.mic,
    'camera': Icons.camera_alt,
    'screen': Icons.screenshot_monitor,
    'document': Icons.description,
  };

  static const Map<String, Color> _typeColors = {
    'text': Colors.blue,
    'voice': Colors.green,
    'camera': Colors.orange,
    'screen': Colors.purple,
    'document': Colors.teal,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeIcon = _typeIcons[entry.type] ?? Icons.history;
    final typeColor = _typeColors[entry.type] ?? Colors.grey;
    final timeStr = _formatTime(entry.timestamp);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryTeal.withOpacity(0.1) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primaryTeal : theme.dividerColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (v) => onSelectionChanged(v ?? false),
                    activeColor: AppTheme.primaryTeal,
                  ),
                ] else ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(typeIcon, size: 18, color: typeColor),
                  ),
                ],
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.sourceText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (entry.isStarred)
                            Icon(Icons.star, size: 16, color: Colors.amber[600]),
                        ],
                      ),
                      const Gap(4),
                      Text(
                        entry.targetText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          _LangChip(lang: entry.sourceLang),
                          const Gap(4),
                          Icon(Icons.arrow_forward, size: 14, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                          const Gap(4),
                          _LangChip(lang: entry.targetLang),
                          const Spacer(),
                          Text(
                            timeStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes}m lalu';
    if (diff.inDays < 1) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _LangChip extends StatelessWidget {
  final String lang;

  const _LangChip({required this.lang});

  static const Map<String, String> _labels = {
    'en': 'EN',
    'id': 'ID',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _labels[lang] ?? lang.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppTheme.primaryTeal,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String text;
  final String? lang;

  const _DetailRow({required this.label, required this.text, this.lang});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$label: ', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (lang != null) _LangChip(lang: lang!),
          ],
        ),
        const Gap(4),
        SelectableText(text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}