import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/clinical_note_models.dart';
import '../services/clinical_note_service.dart';

// espace personnel du psychologue pour ses notes post-seance sur un patient
// (cf CDC section 4.2). Strictement prive : jamais visible par le patient,
// l'admin, ou un autre psychologue - pas dans la maquette, design libre
class ClinicalNotesScreen extends StatefulWidget {
  const ClinicalNotesScreen({
    super.key,
    required this.patientId,
    this.patientName,
  });

  final int patientId;
  final String? patientName;

  @override
  State<ClinicalNotesScreen> createState() => _ClinicalNotesScreenState();
}

class _ClinicalNotesScreenState extends State<ClinicalNotesScreen> {
  final _service = ClinicalNoteService();

  bool _loading = true;
  String? _error;
  List<ClinicalNote> _notes = [];

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
      final notes = await _service.getMyNotesForPatient(widget.patientId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Impossible de charger vos notes.';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({ClinicalNote? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteEditorSheet(
        patientId: widget.patientId,
        existing: existing,
        service: _service,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(ClinicalNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette note ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteNote(note.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Échec de la suppression.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Notes cliniques',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            if (widget.patientName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  widget.patientName!,
                  style:
                      const TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: AppColors.teal),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Visibles par vous seule. Ni le patient ni un autre '
                      'psy n\'y a accès.',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else if (_notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Aucune note pour le moment.',
                  style: TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              )
            else
              for (final note in _notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NoteCard(
                    note: note,
                    onTap: () => _openEditor(existing: note),
                    onDelete: () => _delete(note),
                  ),
                ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            onPressed: () => _openEditor(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Nouvelle note'),
          ),
        ),
      ),
    );
  }
}

const _kMonths = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap, required this.onDelete});

  final ClinicalNote note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = note.updatedAt;
    final time = d.minute == 0
        ? '${d.hour} h'
        : '${d.hour} h ${d.minute.toString().padLeft(2, '0')}';
    final dateLabel = '${d.day} ${_kMonths[d.month - 1]} ${d.year} · $time';

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 20, color: AppColors.muted),
                    onSelected: (v) {
                      if (v == 'edit') onTap();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Supprimer',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  note.content,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.55,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({
    required this.patientId,
    required this.service,
    this.existing,
  });

  final int patientId;
  final ClinicalNoteService service;
  final ClinicalNote? existing;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final _content = TextEditingController(text: widget.existing?.content ?? '');
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_content.text.trim().isEmpty) {
      setState(() => _error = 'La note ne peut pas être vide.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final request = CreateOrUpdateClinicalNoteRequest(
        content: _content.text.trim(),
        appointmentId: widget.existing?.appointmentId,
      );
      if (widget.existing == null) {
        await widget.service.createNote(widget.patientId, request);
      } else {
        await widget.service.updateNote(widget.existing!.id, request);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : "Échec de l'enregistrement.";
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Text(
                  widget.existing == null ? 'Nouvelle note' : 'Modifier la note',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.text),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Visible uniquement par vous.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14.5),
                ),
                const SizedBox(height: 14),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _content,
                  maxLines: 8,
                  autofocus: widget.existing == null,
                  decoration: const InputDecoration(
                    hintText: 'Observations post-séance…',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
