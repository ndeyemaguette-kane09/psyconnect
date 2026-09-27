import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
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
        _error =
            e is ApiException ? e.message : 'Impossible de charger le journal.';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({JournalEntry? entry}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JournalEntrySheet(
        entry: entry,
        journalService: _journalService,
        onDelete: entry == null ? null : () => _delete(entry),
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
                style: TextStyle(color: AppColors.danger)),
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
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: AppErrorState(message: _error!, onRetry: _load),
          ),
        ],
      );
    }

    if (_entries.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 70),
            child: AppEmptyState(
              icon: Icons.book_outlined,
              title: 'Votre journal est vide',
              message: 'Écrire quelques lignes sur votre journée aide à '
                  'repérer ce qui revient. Vous seul y avez accès.',
              actionLabel: 'Écrire ma première entrée',
              onAction: () => _openEditor(),
            ),
          ),
        ],
      );
    }

    final children = <Widget>[
      _WriteRow(onTap: () => _openEditor()),
    ];
    String? currentMonth;
    for (final entry in _entries) {
      final d = entry.createdAt;
      final month = '${_kMonths[d.month - 1].toUpperCase()} ${d.year}';
      if (month != currentMonth) {
        currentMonth = month;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
          child: Text(
            month,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.tealDark,
            ),
          ),
        ));
      }
      children.add(_JournalEntryRow(
        entry: entry,
        onTap: () => _openEditor(entry: entry),
      ));
    }
    children.add(Container(height: 1, color: AppColors.border));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: children,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Humeur
// ─────────────────────────────────────────────────────────────────────────────

const _moodLabels = {
  1: 'Très difficile',
  2: 'Difficile',
  3: 'Neutre',
  4: 'Plutôt bien',
  5: 'Très bien',
};

String _moodLabel(int rating) => _moodLabels[rating] ?? 'Neutre';

class _MoodScale extends StatelessWidget {
  const _MoodScale({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(5, (i) {
            final rating = i + 1;
            final selected = value == rating;
            return Expanded(
              child: Center(
                child: _MoodPoint(
                  rating: rating,
                  selected: selected,
                  onTap: () => onChanged(selected ? null : rating),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Text('Très difficile',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            Spacer(),
            Text('Très bien',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 20,
          child: Center(
            child: Text(
              value == null
                  ? 'Facultatif — vous pouvez écrire sans noter votre humeur.'
                  : _moodLabel(value!),
              style: TextStyle(
                fontSize: 13,
                fontWeight: value == null ? FontWeight.w400 : FontWeight.w700,
                color: value == null ? AppColors.faint : AppColors.tealDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodPoint extends StatelessWidget {
  const _MoodPoint({
    required this.rating,
    required this.selected,
    required this.onTap,
  });

  final int rating;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${_moodLabel(rating)}, $rating sur 5',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: Curves.easeOut,
              width: selected ? 44 : 38,
              height: selected ? 44 : 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.teal : AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.teal : AppColors.borderStrong,
                  width: selected ? 0 : 1.4,
                ),
              ),
              child: Text(
                '$rating',
                style: TextStyle(
                  fontSize: selected ? 17 : 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _kMonths = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

const _kWeekdays = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
];

class _WriteRow extends StatelessWidget {
  const _WriteRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.borderStrong),
      ),
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 19, color: AppColors.teal),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Écrire quelque chose…',
                  style: TextStyle(fontSize: 14.5, color: AppColors.faint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalEntryRow extends StatelessWidget {
  const _JournalEntryRow({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  String get _formattedDate {
    final d = entry.createdAt;
    return '${_kWeekdays[d.weekday - 1]} ${d.day} · '
        '${d.hour.toString().padLeft(2, '0')}h'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formattedDate,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    if (entry.moodRating != null)
                      Text(
                        _moodLabel(entry.moodRating!),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealDark,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Feuille de création / édition
// ─────────────────────────────────────────────────────────────────────────────

class _JournalEntrySheet extends StatefulWidget {
  const _JournalEntrySheet({
    this.entry,
    required this.journalService,
    this.onDelete,
  });

  final JournalEntry? entry;
  final JournalService journalService;
  final VoidCallback? onDelete;

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
    if (_saving) return;
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
    final theme = Theme.of(context);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Modifier l\'entrée' : 'Nouvelle entrée',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Vous seul avez accès à ce journal.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text(
                'Comment s\'est passée votre journée ?',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 14),
              _MoodScale(
                value: _moodRating,
                onChanged: (v) => setState(() => _moodRating = v),
              ),

              const SizedBox(height: 22),
              TextField(
                controller: _controller,
                maxLines: 7,
                minLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Écrivez librement…',
                  alignLabelWithHint: true,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(isEditing ? 'Enregistrer' : 'Ajouter au journal'),
              ),
              if (isEditing && widget.onDelete != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          Navigator.of(context).pop(false);
                          widget.onDelete!();
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const Text('Supprimer cette entrée'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
