import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../patient/models/report_models.dart';
import '../services/admin_service.dart';

// onglet "Signalements" : liste des signalements psychologues soumis par
// des patients. GET /admin/reports + PATCH /admin/reports/{id} pour traiter.
// Filtre par statut (Tous / En attente / Traités / Rejetés).
class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  final _service = AdminService();

  bool _loading = true;
  String? _error;
  List<ReportModel> _reports = [];
  // filtre local (null = tous)
  String? _statusFilter; // null | 'PENDING' | 'REVIEWED' | 'DISMISSED'

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
      final list = await _service.listReports(status: _statusFilter);
      if (!mounted) return;
      setState(() => _reports = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger les signalements.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String? status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _load();
  }

  // ouvre la fiche détail + actions
  void _showDetail(ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportDetailSheet(
        report: report,
        adminService: _service,
        onUpdated: (updated) {
          setState(() {
            _reports = [
              for (final r in _reports) if (r.id == updated.id) updated else r,
            ];
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            // en-tête + filtres
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signalements',
                      style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Tous',
                          selected: _statusFilter == null,
                          onTap: () => _applyFilter(null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'En attente',
                          selected: _statusFilter == 'PENDING',
                          onTap: () => _applyFilter('PENDING'),
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Traités',
                          selected: _statusFilter == 'REVIEWED',
                          onTap: () => _applyFilter('REVIEWED'),
                          color: AppColors.teal,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Rejetés',
                          selected: _statusFilter == 'DISMISSED',
                          onTap: () => _applyFilter('DISMISSED'),
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // contenu
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.muted)),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                      onPressed: _load,
                                      child: const Text('Réessayer')),
                                ],
                              ),
                            ),
                          ],
                        )
                      : _reports.isEmpty
                          ? ListView(
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Center(
                                    child: Text(
                                      'Aucun signalement pour le moment.',
                                      style:
                                          TextStyle(color: AppColors.muted),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                              itemCount: _reports.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _ReportCard(
                                report: _reports[i],
                                onTap: () => _showDetail(_reports[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// carte résumée d'un signalement dans la liste
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final ReportModel report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (report.status) {
      'PENDING' => Colors.orange,
      'REVIEWED' => AppColors.teal,
      'DISMISSED' => AppColors.muted,
      _ => AppColors.muted,
    };

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // icône signalement
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag, color: AppColors.tealDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.reasonLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          report.statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Psy #${report.psychologistProfileId} · Patient #${report.patientProfileId}',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12),
                  ),
                  if (report.description != null &&
                      report.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      report.description!,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (report.hasEvidence) ...[
                        const Icon(Icons.attach_file,
                            color: AppColors.teal, size: 14),
                        const SizedBox(width: 4),
                        const Text('Preuve jointe',
                            style: TextStyle(
                                color: AppColors.teal, fontSize: 11)),
                        const SizedBox(width: 12),
                      ],
                      if (report.createdAt != null)
                        Text(
                          _formatDate(report.createdAt!),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// fiche détail + actions admin (traiter / rejeter + note)
class _ReportDetailSheet extends StatefulWidget {
  const _ReportDetailSheet({
    required this.report,
    required this.adminService,
    required this.onUpdated,
  });

  final ReportModel report;
  final AdminService adminService;
  final ValueChanged<ReportModel> onUpdated;

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  final _noteController = TextEditingController();
  bool _busy = false;
  bool _openingEvidence = false;
  String? _evidenceError;
  String? _actionError;
  late ReportModel _report;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    if (_report.adminNote != null) {
      _noteController.text = _report.adminNote!;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _doAction(String status) async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final updated = await widget.adminService.reviewReport(
        _report.id,
        status: status,
        adminNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _report = updated);
      widget.onUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'REVIEWED'
              ? 'Signalement marqué comme traité.'
              : 'Signalement rejeté.'),
        ),
      );
    } catch (e) {
      setState(() => _actionError = 'Action impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEvidence() async {
    setState(() {
      _openingEvidence = true;
      _evidenceError = null;
    });
    try {
      final file =
          await widget.adminService.downloadReportEvidence(_report.id);
      final ext = file.contentType.contains('pdf')
          ? 'pdf'
          : file.contentType.contains('png')
              ? 'png'
              : 'jpg';
      final dir = await getTemporaryDirectory();
      final localFile =
          File('${dir.path}/preuve_signalement_${_report.id}.$ext');
      await localFile.writeAsBytes(file.bytes, flush: true);
      await OpenFilex.open(localFile.path);
    } catch (_) {
      setState(() => _evidenceError = "Impossible d'ouvrir la preuve.");
    } finally {
      if (mounted) setState(() => _openingEvidence = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _report.status == 'PENDING';
    // remonte le contenu au-dessus du clavier virtuel
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
      child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // poignée
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.tealMid,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // titre
              Row(
                children: [
                  const Icon(Icons.flag, color: AppColors.tealDark, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _report.reasonLabel,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // infos
              _InfoRow('Psychologue', 'ID #${_report.psychologistProfileId}'),
              _InfoRow('Patient', 'ID #${_report.patientProfileId}'),
              _InfoRow('Statut', _report.statusLabel),
              if (_report.createdAt != null)
                _InfoRow('Soumis le', _fmtDate(_report.createdAt!)),
              if (_report.description != null &&
                  _report.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Description',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(_report.description!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],

              // pièce jointe
              if (_report.hasEvidence) ...[
                const SizedBox(height: 16),
                if (_evidenceError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_evidenceError!,
                        style: const TextStyle(
                            color: AppColors.rose, fontSize: 12)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openingEvidence ? null : _openEvidence,
                    icon: _openingEvidence
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: const Text('Voir la preuve jointe'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.tealMid),
                    ),
                  ),
                ),
              ],

              // note admin
              const SizedBox(height: 20),
              Text('Note admin (optionnel)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: 'Commentaire interne sur ce signalement…',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.tealMid),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              if (_report.adminNote != null &&
                  _report.adminNote!.isNotEmpty &&
                  _noteController.text.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Note existante : ${_report.adminNote}',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12),
                ),
              ],

              // erreur d'action
              if (_actionError != null) ...[
                const SizedBox(height: 12),
                Text(_actionError!,
                    style:
                        const TextStyle(color: AppColors.rose, fontSize: 12)),
              ],

              // actions
              const SizedBox(height: 20),
              if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : () => _doAction('REVIEWED'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            minimumSize: const Size.fromHeight(44)),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Marquer comme traité'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _doAction('DISMISSED'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.muted,
                            side: const BorderSide(color: AppColors.muted),
                            minimumSize: const Size.fromHeight(44)),
                        child: const Text('Rejeter'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // déjà traité : juste mettre à jour la note
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _doAction(_report.status),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mettre à jour la note'),
                  ),
                ),
              ],
            ],
          ),
        ),
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.teal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withOpacity(0.12)
              : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? activeColor : AppColors.tealMid),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? activeColor : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
