import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../models/journal_models.dart';
import '../services/journal_service.dart';

// Journal privé du patient (CRUD). Le filtrage par utilisateur est fait
// côté backend via le token, aucun patientId n'est donc nécessaire ici.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _journalService = JournalService();

  bool _loading = true;
  String? _error;
  List<JournalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _journalService.getMyEntries();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Impossible de charger le journal.';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({JournalEntry? entry}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JournalEntrySheet(
        entry: entry,
        journalService: _journalService,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette entrée ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer',
                style: TextStyle(color: AppColors.rose)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _journalService.deleteEntry(entry.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Suppression impossible.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon journal'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.rose)),
                      ),
                    ],
                  )
                : _entries.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Aucune entrée pour le moment.\n'
                              'Touchez + pour écrire la première.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final entry = _entries[i];
                          return _JournalEntryCard(
                            entry: entry,
                            onTap: () => _openEditor(entry: entry),
                            onDelete: () => _delete(entry),
                          );
                        },
                      ),
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      'à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(entry.createdAt),
                    style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (entry.moodRating != null) ...[
                  Text(_moodEmoji(entry.moodRating!),
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(_moodLabel(entry.moodRating!),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.teal)),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.muted),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// Emoji et libellé associés à chaque note d'humeur (1–5). Utilisés à la fois
// dans la carte et dans le sélecteur pour garantir une présentation cohérente.
const _moodEmojis = {1: '😢', 2: '🙁', 3: '😐', 4: '🙂', 5: '😄'};
const _moodLabels = {
  1: 'Très difficile',
  2: 'Difficile',
  3: 'Neutre',
  4: 'Plutôt bien',
  5: 'Très bien',
};

String _moodEmoji(int rating) => _moodEmojis[rating] ?? '😐';
String _moodLabel(int rating) => _moodLabels[rating] ?? 'Neutre';

// Feuille de création ou d'édition d'une entrée de journal.
class _JournalEntrySheet extends StatefulWidget {
  const _JournalEntrySheet({this.entry, required this.journalService});

  final JournalEntry? entry;
  final JournalService journalService;

  @override
  State<_JournalEntrySheet> createState() => _JournalEntrySheetState();
}

class _JournalEntrySheetState extends State<_JournalEntrySheet> {
  late final TextEditingController _controller;
  int? _moodRating;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.entry?.content ?? '');
    _moodRating = widget.entry?.moodRating;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      setState(() => _error = 'Écrivez quelque chose avant d\'enregistrer.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final request = CreateJournalEntryRequest(
      content: content,
      moodRating: _moodRating,
    );

    try {
      if (widget.entry == null) {
        await widget.journalService.createEntry(request);
      } else {
        await widget.journalService.updateEntry(widget.entry!.id, request);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : 'Enregistrement impossible.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.tealMid,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isEditing ? 'Modifier l\'entrée' : 'Nouvelle entrée',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text('Comment vous sentez-vous ?',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(5, (i) {
                final rating = i + 1;
                final selected = _moodRating == rating;
                return ChoiceChip(
                  label: Text('${_moodEmoji(rating)} ${_moodLabel(rating)}'),
                  selected: selected,
                  onSelected: (_) => setState(
                    () => _moodRating = selected ? null : rating,
                  ),
                  selectedColor: AppColors.teal,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: selected ? AppColors.teal : AppColors.tealMid),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'Écrivez librement ici...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.rose)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
