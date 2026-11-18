import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:translate_id/src/core/theme/app_theme.dart';
import 'package:translate_id/src/shared/enums/formality_mode.dart';
import 'package:translate_id/src/shared/widgets/voice_button.dart';

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

  void _showAddPhraseDialog(BuildContext context) {
    final theme = Theme.of(context);
    final sourceController = TextEditingController();
    final formalController = TextEditingController();
    final slangController = TextEditingController();
    String selectedCategory = _categories.first.id;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Frasa Baru'),
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
            onPressed: () {
              // TODO: Save to database
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Frasa ditambahkan')),
              );
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

class _PhraseListView extends StatelessWidget {
  final PhraseCategory category;
  final String searchQuery;
  final FormalityMode displayFormality;

  const _PhraseListView({
    required this.category,
    required this.searchQuery,
    required this.displayFormality,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mock data - replace with database query
    final phrases = _getMockPhrases(category.id);

    final filtered = phrases.where((p) =>
      p.source.toLowerCase().contains(searchQuery.toLowerCase()) ||
      p.formal.toLowerCase().contains(searchQuery.toLowerCase()) ||
      p.slang.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
            const Gap(16),
            Text(
              searchQuery.isEmpty ? 'Belum ada frasa di kategori ini' : 'Tidak ditemukan',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final phrase = filtered[index];
        return _PhraseCard(
          phrase: phrase,
          displayFormality: displayFormality,
          categoryColor: category.color,
        );
      },
    );
  }

  List<_MockPhrase> _getMockPhrases(String categoryId) {
    switch (categoryId) {
      case 'emergency':
        return [
          _MockPhrase('Help!', 'Tolong!', 'Tolong dong!'),
          _MockPhrase('Call the police!', 'Hubungi polisi!', 'Telpon polisi dong!'),
          _MockPhrase('I need a doctor', 'Saya butuh dokter', 'Gue butuh dokter nih'),
          _MockPhrase('Where is the hospital?', 'Di mana rumah sakitnya?', 'Rumah sakitnya di mana sih?'),
          _MockPhrase('I\'m lost', 'Saya tersesat', 'Gue kesasar nih'),
        ];
      case 'transport':
        return [
          _MockPhrase('Where is the bus stop?', 'Di mana halte busnya?', 'Haltenya di mana ya?'),
          _MockPhrase('How much is the fare?', 'Berapa ongkosnya?', 'Ongkosnya berapa sih?'),
          _MockPhrase('I want to go to...', 'Saya mau ke...', 'Gue mau ke...'),
          _MockPhrase('Does this go to...?', 'Apakah ini ke...?', 'Ini ke... nggak?'),
          _MockPhrase('One ticket, please', 'Satu tiket, tolong', 'Satu tiket ya'),
        ];
      case 'food':
        return [
          _MockPhrase('I\'m hungry', 'Saya lapar', 'Gue lapar nih'),
          _MockPhrase('What do you recommend?', 'Apa rekomendasinya?', 'Recomend nya apa?'),
          _MockPhrase('No spicy, please', 'Tidak pedas, tolong', 'Nggak pedes ya'),
          _MockPhrase('The bill, please', 'Bonnya, tolong', 'Bon ya'),
          _MockPhrase('Delicious!', 'Enak sekali!', 'Enak banget!'),
        ];
      case 'shopping':
        return [
          _MockPhrase('How much is this?', 'Ini berapa harganya?', 'Ini berapa ya?'),
          _MockPhrase('Too expensive', 'Terlalu mahal', 'Mahal banget'),
          _MockPhrase('Can you lower the price?', 'Bisa ditawar?', 'Bisa nggak ditawar?'),
          _MockPhrase('I\'ll take it', 'Saya beli ini', 'Gue ambil ini'),
          _MockPhrase('Do you have...?', 'Apakah ada...?', 'Ada... nggak?'),
        ];
      case 'work':
        return [
          _MockPhrase('Good morning', 'Selamat pagi', 'Pagi'),
          _MockPhrase('See you tomorrow', 'Sampai jumpa besok', 'Dah jumpa besok'),
          _MockPhrase('I\'ll send the file', 'Saya kirim filenya', 'Gue kirim filenya ya'),
          _MockPhrase('Meeting at 2 PM', 'Rapat jam 2 siang', 'Meeting jam 2'),
          _MockPhrase('Thank you for your help', 'Terima kasih atas bantuannya', 'Makasih ya bantuannya'),
        ];
      case 'slang':
        return [
          _MockPhrase('What\'s up?', 'Apa kabar?', 'Gimana kabarnya? / Apa kabar?'),
          _MockPhrase('No way!', 'Tidak mungkin!', 'Nggak mungkin deh! / Emang nggak bisa!'),
          _MockPhrase('Are you serious?', 'Apakah kamu serius?', 'Beneran? / Serius?'),
          _MockPhrase('Whatever', 'Terserah', 'Bebas aja / Terserah lu'),
          _MockPhrase('No problem', 'Tidak masalah', 'Nggak apa-apa / Enggak masala'),
        ];
      default:
        return [];
    }
  }
}

class _MockPhrase {
  final String source;
  final String formal;
  final String slang;

  _MockPhrase(this.source, this.formal, this.slang);
}

class _PhraseCard extends StatelessWidget {
  final _MockPhrase phrase;
  final FormalityMode displayFormality;
  final Color categoryColor;

  const _PhraseCard({
    required this.phrase,
    required this.displayFormality,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetText = displayFormality == FormalityMode.formal ? phrase.formal : phrase.slang;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // TODO: Copy to translation page
        },
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
                  Text(
                    phrase.source,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
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
                    icon: Icon(Icons.star_border_outlined, color: AppTheme.primaryTeal),
                    onPressed: () {
                      // TODO: Star
                    },
                    tooltip: 'Favorit',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.content_copy_outlined, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () {
                      // TODO: Copy
                    },
                    tooltip: 'Salin',
                  ),
                ],
              ),
              if (displayFormality == FormalityMode.formal && phrase.slang != phrase.formal) ...[
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Tidak formal: ${phrase.slang}',
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