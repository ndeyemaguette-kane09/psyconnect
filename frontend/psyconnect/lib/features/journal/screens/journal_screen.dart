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
      Text('Mon journal', style: Theme.of(context).textTheme.displayMedium),
      const SizedBox(height: 6),
      const Row(
        children: [
          Icon(Icons.lock_outline, size: 15, color: AppColors.muted),
          SizedBox(width: 6),
          Text(
            'Vous seul y avez accès.',
            style: TextStyle(fontSize: 15, color: AppColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _WriteRow(onTap: () => _openEditor()),
    ];
    String? currentMonth;
    for (final entry in _entries) {
      final d = entry.createdAt;
      final monthName = _kMonths[d.month - 1];
      final month =
          '${monthName[0].toUpperCase()}${monthName.substring(1)} ${d.year}';
      if (month != currentMonth) {
        currentMonth = month;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(0, 28, 0, 4),
          child: Text(
            month,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ));
      }
      children.add(_JournalEntryRow(
        entry: entry,
        onTap: () => _openEditor(entry: entry),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
      children: children,
    );
  }
}

const _moodColors = {
  1: Color(0xFFB5532F),
  2: Color(0xFFC97B54),
  3: Color(0xFFD2A04A),
  4: Color(0xFF6E9384),
  5: Color(0xFF1E4D43),
};

class _MoodShape extends StatelessWidget {
  const _MoodShape({required this.rating, this.size = 36});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _moodColors[rating] ?? AppColors.gold;
    final r = size / 2;
    switch (rating) {
      case 1:
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: size * 0.72,
                height: size * 0.72,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(size * 0.12),
                ),
              ),
            ),
          ),
        );
      case 2:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
        );
      case 3:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(r),
              bottom: Radius.circular(size * 0.15),
            ),
          ),
        );
      case 4:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(r),
              topRight: Radius.circular(r),
              bottomLeft: Radius.circular(r),
              bottomRight: Radius.circular(size * 0.15),
            ),
          ),
        );
      default:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
    }
  }
}

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
                  dimmed: value != null && !selected,
                  onTap: () => onChanged(selected ? null : rating),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 22,
          child: Center(
            child: Text(
              value == null
                  ? 'Facultatif : vous pouvez écrire sans choisir.'
                  : _moodLabel(value!),
              style: TextStyle(
                fontSize: value == null ? 14 : 16,
                fontWeight: value == null ? FontWeight.w400 : FontWeight.w800,
                color: value == null
                    ? AppColors.muted
                    : (_moodColors[value!] ?? AppColors.text),
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
    required this.dimmed,
    required this.onTap,
  });

  final int rating;
  final bool selected;
  final bool dimmed;
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
          width: 58,
          height: 58,
          child: Center(
            child: AnimatedOpacity(
              duration: AppMotion.fast,
              opacity: dimmed ? 0.3 : 1,
              child: AnimatedScale(
                duration: AppMotion.fast,
                scale: selected ? 1.15 : 1,
                child: _MoodShape(rating: rating, size: 38),
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
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Comment s\'est passée votre journée ?',
                  style: TextStyle(fontSize: 16, color: AppColors.muted),
                ),
              ),
              Icon(Icons.edit_outlined, size: 20, color: AppColors.teal),
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
        '${d.hour.toString().padLeft(2, '0')} h '
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final mood = entry.moodRating;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: mood == null
                    ? Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 5, left: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.borderStrong,
                          shape: BoxShape.circle,
                        ),
                      )
                    : Align(
                        alignment: Alignment.topLeft,
                        child: _MoodShape(rating: mood, size: 22),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mood == null
                        ? _formattedDate
                        : '$_formattedDate · ${_moodLabel(mood)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Feuille de création / édition

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
                style: theme.textTheme.displaySmall,
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
              const Text(
                'Comment vous sentez-vous ?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
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
                style: const TextStyle(fontSize: 16.5, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Écrivez librement, sans vous juger',
                  alignLabelWithHint: true,
                  fillColor: AppColors.background,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 14.5),
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
