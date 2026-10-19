import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/models/report_models.dart';
import '../services/admin_service.dart';

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
  Map<int, PsychologistProfile> _psyById = {};
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
      if (_psyById.isEmpty) {
        try {
          final psys = await _service.listPsychologists();
          _psyById = {for (final p in psys) p.id: p};
        } catch (_) {
          _psyById = {};
        }
      }
      if (!mounted) return;
      setState(() => _reports = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger les signalements.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _psychologistLabel(ReportModel report) {
    final psy = _psyById[report.psychologistProfileId];
    if (psy == null) {
      return 'Psychologue #${report.psychologistProfileId}';
    }
    final details = [
      if (psy.specialty.trim().isNotEmpty) psy.specialty.trim(),
      if (psy.city != null && psy.city!.trim().isNotEmpty) psy.city!.trim(),
    ].join(' · ');
    return details.isEmpty ? psy.fullName : '${psy.fullName} — $details';
  }

  void _applyFilter(String? status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _load();
  }

  void _showDetail(ReportModel report) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ReportDetailSheet(
        report: report,
        psychologistName: _psychologistName(report),
        psychologistLabel: _psychologistLabel(report),
        adminService: _service,
        onUpdated: (updated) {
          setState(() {
            _reports = [
              for (final r in _reports) if (r.id == updated.id) updated else r,
            ];
          });
        },
      ),
    ));
  }

  String _psychologistName(ReportModel report) =>
      _psyById[report.psychologistProfileId]?.fullName ??
      'Psychologue #${report.psychologistProfileId}';

  String _psychologistDetails(ReportModel report) {
    final psy = _psyById[report.psychologistProfileId];
    if (psy == null) return '';
    return [
      if (psy.specialty.trim().isNotEmpty) psy.specialty.trim(),
      if (psy.city != null && psy.city!.trim().isNotEmpty) psy.city!.trim(),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _reports.where((r) => r.status == 'PENDING').length;
    const filters = [
      ('PENDING', 'En attente'),
      ('REVIEWED', 'Traités'),
      ('DISMISSED', 'Rejetés'),
      (null, 'Tous'),
    ];

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Signalements',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (value, label) in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: value == 'PENDING' &&
                                _statusFilter == 'PENDING' &&
                                pendingCount > 0
                            ? '$label ($pendingCount)'
                            : label,
                        selected: _statusFilter == value,
                        onTap: () => _applyFilter(value),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else if (_reports.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Aucun signalement pour le moment.',
                  style: TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              )
            else
              for (final r in _reports)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReportCard(
                    report: r,
                    psychologistName: _psychologistName(r),
                    psychologistDetails: _psychologistDetails(r),
                    onTap: () => _showDetail(r),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

const _kMonths = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _formatDate(DateTime d) => '${d.day} ${_kMonths[d.month - 1]} ${d.year}';

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pending = status == 'PENDING';
    final color = switch (status) {
      'PENDING' => AppColors.gold,
      'DISMISSED' => AppColors.danger,
      _ => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: pending ? AppColors.text : Colors.white,
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.psychologistName,
    required this.psychologistDetails,
    required this.onTap,
  });

  final ReportModel report;
  final String psychologistName;
  final String psychologistDetails;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      'Par un patient anonyme',
      if (report.hasEvidence) 'preuve jointe',
      if (report.createdAt != null) _formatDate(report.createdAt!),
    ].join(' · ');

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      report.reasonLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusLabel(
                      status: report.status, label: report.statusLabel),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  AppAvatar(name: psychologistName, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          psychologistName,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        if (psychologistDetails.isNotEmpty)
                          Text(
                            psychologistDetails,
                            style: const TextStyle(
                                fontSize: 13.5, color: AppColors.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (report.description != null &&
                  report.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '« ${report.description!.trim()} »',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                meta,
                style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportDetailSheet extends StatefulWidget {
  const _ReportDetailSheet({
    required this.report,
    required this.psychologistName,
    required this.psychologistLabel,
    required this.adminService,
    required this.onUpdated,
  });

  final ReportModel report;
  final String psychologistName;
  final String psychologistLabel;
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

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _report.reasonLabel,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _StatusLabel(status: _report.status, label: _report.statusLabel),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                AppAvatar(name: widget.psychologistName, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.psychologistLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow('Signalé par', 'Un patient anonyme'),
          if (_report.createdAt != null)
            _InfoRow('Le', _formatDate(_report.createdAt!)),
          if (_report.description != null &&
              _report.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: Text(
                '« ${_report.description!.trim()} »',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: AppColors.text,
                ),
              ),
            ),
          if (_report.hasEvidence) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _openingEvidence ? null : _openEvidence,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.text,
                ),
                icon: _openingEvidence
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file, size: 20),
                label: const Text('Voir la preuve jointe'),
              ),
            ),
            if (_evidenceError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  _evidenceError!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 14),
                ),
              ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 26, 4, 10),
            child: Text(
              'Note interne',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          TextField(
            controller: _noteController,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(
              hintText: 'Visible uniquement par l\'équipe (optionnel)',
            ),
          ),
          if (_actionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                _actionError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 14),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 10, 20, 14 + MediaQuery.of(context).viewInsets.bottom),
          child: _busy
              ? const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              : isPending
                  ? Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _doAction('REVIEWED'),
                            child: const Text('Marquer traité'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _doAction('DISMISSED'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.sand,
                              foregroundColor: AppColors.text,
                            ),
                            child: const Text('Rejeter'),
                          ),
                        ),
                      ],
                    )
                  : FilledButton(
                      onPressed: () => _doAction(_report.status),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sand,
                        foregroundColor: AppColors.text,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Mettre à jour la note'),
                    ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, color: AppColors.muted),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal : AppColors.sand,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.background : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
