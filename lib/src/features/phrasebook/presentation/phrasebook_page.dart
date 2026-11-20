import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/services/database/app_database.dart';
import 'package:translate_id/src/shared/enums/formality_mode.dart';
import 'package:translate_id/src/shared/widgets/formality_toggle.dart';
import 'package:translate_id/src/shared/widgets/voice_button.dart';
import 'package:translate_id/src/features/settings/providers/settings_providers.dart';

class PhrasebookPage extends ConsumerStatefulWidget {
  const PhrasebookPage({super.key});

  @override
  ConsumerState<PhrasebookPage> createState() => _PhrasebookPageState();
}

class _PhrasebookPageState extends ConsumerState<PhrasebookPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  FormalityMode _displayFormality = FormalityMode.formal;

  static const List<PhraseCategory> _categories = [
    PhraseCategory(id: 'emergency', label: 'Darurat', icon: Icons.emergency_outlined, color: Colors.red),
    PhraseCategory(id: 'transport', label: 'Transport', icon: Icons.directions_bus_outlined, color: Colors.blue),
    PhraseCategory(id: 'food', label: 'Makan & Minum', icon: Icons.restaurant_outlined, color: Colors.orange),
    PhraseCategory(id: 'shopping', label: 'Belanja', icon: Icons.shopping_bag_outlined, color: Colors.green),
    PhraseCategory(id: 'work', label: 'Kerja', icon: Icons.work_outline, color: Colors.purple),
    PhraseCategory(id: 'slang', label: 'Slang/Gaul', icon: Icons.chat_bubble_outline, color: Colors.pink),
    PhraseCategory(id: 'favorites', label: 'Favorit', icon: Icons.star, color: Colors.amber),
    PhraseCategory(id: 'custom', label: 'Kustom', icon: Icons.star_outline, color: Colors.amber),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
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
        title: const Text('Frasebook'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: theme.textTheme.labelMedium,
              indicatorColor: AppTheme.primaryTeal,
              indicatorWeight: 3,
              labelColor: AppTheme.primaryTeal,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: _categories.map((cat) => Tab(
                icon: Icon(cat.icon, size: 20),
                text: cat.label,
              )).toList(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search + Formality toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari frasa...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const Gap(12),
                FormalityToggle(
                  value: _displayFormality,
                  onChanged: (v) => setState(() => _displayFormality = v),
                ),
              ],
            ),
          ),

          // Phrase list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) {
                return _PhraseListView(
                  category: category,
                  searchQuery: _searchQuery,
                  displayFormality: _displayFormality,
                  onEdit: _showAddPhraseDialog,
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Tambah Frasa'),
        onPressed: () => _showAddPhraseDialog(context),
      ),
    );
  }

  Future<void> _showAddPhraseDialog(BuildContext context, {PhrasebookEntry? existing}) async {
    final db = ref.read(appDatabaseProvider);
    final theme = Theme.of(context);
    final sourceController = TextEditingController(text: existing?.sourceText ?? '');
    final formalController = TextEditingController(text: existing?.targetTextFormal ?? '');
    final slangController = TextEditingController(text: existing?.targetTextSlang ?? '');
    String selectedCategory = existing?.category ?? _categories.first.id;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Tambah Frasa Baru' : 'Edit Frasa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: _categories.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.label),
                )).toList(),
                onChanged: (v) => selectedCategory = v ?? _categories.first.id,
              ),
              const Gap(16),
              TextField(
                controller: sourceController,
                decoration: const InputDecoration(labelText: 'Teks Asli (EN/ID)'),
              ),
              const Gap(16),
              TextField(
                controller: formalController,
                decoration: const InputDecoration(labelText: 'Terjemahan Formal'),
              ),
              const Gap(16),
              TextField(
                controller: slangController,
                decoration: const InputDecoration(labelText: 'Terjemahan Tidak Formal'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final source = sourceController.text.trim();
              final formal = formalController.text.trim();
              final slang = slangController.text.trim();
              if (source.isEmpty || formal.isEmpty || slang.isEmpty) return;

              if (existing == null) {
                await db.addPhrase(
                  category: selectedCategory,
                  sourceText: source,
                  targetTextFormal: formal,
                  targetTextSlang: slang,
                  isCustom: true,
                );
              } else {
                await db.updatePhrase(existing.id,
                  category: selectedCategory,
                  sourceText: source,
                  targetTextFormal: formal,
                  targetTextSlang: slang,
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(existing == null ? 'Frasa ditambahkan' : 'Frasa diperbarui')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class PhraseCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const PhraseCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _PhraseListView extends ConsumerWidget {
  final PhraseCategory category;
  final String searchQuery;
  final FormalityMode displayFormality;
  final void Function(BuildContext, {PhrasebookEntry? existing}) onEdit;

  const _PhraseListView({
    required this.category,
    required this.searchQuery,
    required this.displayFormality,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final theme = Theme.of(context);

    final phrasesAsync = category.id == 'custom'
        ? db.getAllPhrases(category: null).asStream()
        : (category.id == 'favorites'
            ? db.getFavoritePhrases().asStream()
            : db.getAllPhrases(category: category.id).asStream());

    return StreamBuilder<List<PhrasebookEntry>>(
      stream: phrasesAsync,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final phrases = snapshot.data ?? [];
        final filtered = phrases.where((p) =>
          p.sourceText.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.targetTextFormal.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.targetTextSlang.toLowerCase().contains(searchQuery.toLowerCase())
        ).toList();

        // For custom tab, only show isCustom=true
        final displayPhrases = category.id == 'custom'
            ? filtered.where((p) => p.isCustom).toList()
            : filtered;

        if (displayPhrases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
                const Gap(16),
                Text(
                  searchQuery.isEmpty 
                    ? (category.id == 'custom' ? 'Belum ada frasa kustom' : 'Belum ada frasa di kategori ini')
                    : 'Tidak ditemukan',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: displayPhrases.length,
          itemBuilder: (context, index) {
            final phrase = displayPhrases[index];
            return _PhraseCard(
              phrase: phrase,
              displayFormality: displayFormality,
              categoryColor: category.color,
              onToggleFavorite: () => db.togglePhraseFavorite(phrase.id, !phrase.isFavorite),
              onEdit: () => onEdit(context, existing: phrase),
              onDelete: () => _confirmDelete(context, phrase),
              onTap: () => _copyToTranslationPage(context, phrase),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, PhrasebookEntry phrase) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Frasa?'),
        content: Text('Frasa "${phrase.sourceText}" akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(appDatabaseProvider).deletePhrase(phrase.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Frasa dihapus')));
      }
    }
  }

  void _copyToTranslationPage(BuildContext context, PhrasebookEntry phrase) {
    final text = displayFormality == FormalityMode.formal ? phrase.targetTextFormal : phrase.targetTextSlang;
    // TODO: Navigate to translation page with pre-filled text
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disalin: $text')));
  }
}

class _PhraseCard extends StatelessWidget {
  final PhrasebookEntry phrase;
  final FormalityMode displayFormality;
  final Color categoryColor;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PhraseCard({
    required this.phrase,
    required this.displayFormality,
    required this.categoryColor,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetText = displayFormality == FormalityMode.formal ? phrase.targetTextFormal : phrase.targetTextSlang;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      phrase.sourceText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      targetText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const Gap(8),
                  IconButton(
                    icon: Icon(Icons.volume_up_outlined, color: AppTheme.primaryTeal),
                    onPressed: () {
                      // TODO: TTS playback
                    },
                    tooltip: 'Dengarkan',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                    ),
                  ),
                  IconButton(
                    icon: Icon(phrase.isFavorite ? Icons.star : Icons.star_border_outlined, color: AppTheme.primaryTeal),
                    onPressed: onToggleFavorite,
                    tooltip: phrase.isFavorite ? 'Hapus favorit' : 'Favorit',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Hapus',
                  ),
                ],
              ),
              if (displayFormality == FormalityMode.formal && phrase.targetTextSlang != phrase.targetTextFormal) ...[
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Tidak formal: ${phrase.targetTextSlang}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

