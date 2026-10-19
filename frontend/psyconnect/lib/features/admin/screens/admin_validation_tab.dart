import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/widgets/psychologist_card.dart';
import '../services/admin_service.dart';
import '../widgets/page_controls.dart';

// Onglet "Validation" : liste complète des psychologues à valider ou déjà traités
// (le tableau de bord n'en affiche que 3 en aperçu).
class AdminValidationTab extends StatefulWidget {
  const AdminValidationTab({super.key});

  @override
  State<AdminValidationTab> createState() => _AdminValidationTabState();
}

class _AdminValidationTabState extends State<AdminValidationTab> {
  static const _pageSize = 8;

  final _adminService = AdminService();

  bool _loading = true;
  String? _error;
  List<PsychologistProfile> _psychologists = [];
  String? _busyId;

  // Pagination indépendante par section pour éviter qu'un changement de page
  // dans "En attente" ne déplace aussi "Refusés" ou "Vérifiés".
  int _pendingPage = 0;
  int _rejectedPage = 0;
  int _verifiedPage = 0;
  _Section _section = _Section.pending;

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
      final list = await _adminService.listPsychologists();
      if (!mounted) return;
      setState(() {
        _psychologists = list;
        _pendingPage = 0;
        _rejectedPage = 0;
        _verifiedPage = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les psychologues.';
        _loading = false;
      });
    }
  }

  Future<void> _setVerified(PsychologistProfile psy, bool verified) async {
    setState(() => _busyId = '${psy.id}');
    try {
      final updated =
          await _adminService.setPsychologistVerified(psy.id, verified);
      if (!mounted) return;
      setState(() {
        _psychologists = [
          for (final p in _psychologists) if (p.id == updated.id) updated else p,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible pour le moment.')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // Distinct de _setVerified : "refuser" déplace le profil de "En attente"
  // vers "Refusés". Passer verified=false n'a aucun effet sur un profil en attente
  // (il est déjà à false), d'où l'usage de l'endpoint rejected dédié.
  Future<void> _setRejected(PsychologistProfile psy, bool rejected) async {
    setState(() => _busyId = '${psy.id}');
    try {
      final updated =
          await _adminService.setPsychologistRejected(psy.id, rejected);
      if (!mounted) return;
      setState(() {
        _psychologists = [
          for (final p in _psychologists) if (p.id == updated.id) updated else p,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible pour le moment.')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  List<PsychologistProfile> get _pending =>
      _psychologists.where((p) => !p.profileVerified && !p.rejected).toList();

  List<PsychologistProfile> get _rejected =>
      _psychologists.where((p) => p.rejected).toList();

  List<PsychologistProfile> get _verified =>
      _psychologists.where((p) => p.profileVerified).toList();

  List<_CardAction> _actionsFor(PsychologistProfile psy) {
    if (psy.profileVerified) {
      return [
        _CardAction('Retirer la vérification', false,
            () => _setVerified(psy, false)),
      ];
    }
    if (psy.rejected) {
      return [
        _CardAction('Accepter', true,
            psy.hasLicenseDocument ? () => _setVerified(psy, true) : null),
        _CardAction(
            'Remettre en attente', false, () => _setRejected(psy, false)),
      ];
    }
    return [
      _CardAction('Accepter', true,
            psy.hasLicenseDocument ? () => _setVerified(psy, true) : null),
      _CardAction('Refuser', false, () => _setRejected(psy, true)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<PsychologistProfile> items;
    final int page;
    final ValueChanged<int> onPage;
    final String empty;
    switch (_section) {
      case _Section.pending:
        items = _pending;
        page = _pendingPage;
        onPage = (p) => setState(() => _pendingPage = p);
        empty = 'Aucune demande en attente.';
      case _Section.rejected:
        items = _rejected;
        page = _rejectedPage;
        onPage = (p) => setState(() => _rejectedPage = p);
        empty = 'Aucun profil refusé.';
      case _Section.verified:
        items = _verified;
        page = _verifiedPage;
        onPage = (p) => setState(() => _verifiedPage = p);
        empty = 'Aucun psychologue vérifié pour le moment.';
    }
    final counts = {
      _Section.pending: _pending.length,
      _Section.rejected: _rejected.length,
      _Section.verified: _verified.length,
    };

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Validations',
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
                  for (final sec in _Section.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Chip(
                        label: '${sec.label} (${counts[sec]})',
                        selected: _section == sec,
                        onTap: () => setState(() => _section = sec),
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
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  empty,
                  style:
                      const TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              )
            else ...[
              for (final psy in paginate(items, page, _pageSize))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PsychologistCard(
                    psychologist: psy,
                    busy: _busyId == '${psy.id}',
                    actions: _actionsFor(psy),
                    onTap: () => _showDetail(psy),
                  ),
                ),
              PageControls(
                page: page,
                pageCount: pageCountFor(items.length, _pageSize),
                onPageChanged: onPage,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Ouvre la fiche détail avant de prendre une décision : tous les champs
  // du profil et le justificatif si fourni.
  void _showDetail(PsychologistProfile psy) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PsychologistDetailPage(
        psychologist: psy,
        adminService: _adminService,
        actions: _actionsFor(psy),
      ),
    ));
  }
}

enum _Section { pending, rejected, verified }

extension on _Section {
  String get label {
    switch (this) {
      case _Section.pending:
        return 'En attente';
      case _Section.rejected:
        return 'Refusés';
      case _Section.verified:
        return 'Vérifiés';
    }
  }
}

class _CardAction {
  const _CardAction(this.label, this.primary, this.run);

  final String label;
  final bool primary;
  final Future<void> Function()? run;
}

class _Chip extends StatelessWidget {
  const _Chip({
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
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.background : AppColors.text,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _actionButton(_CardAction action, {required VoidCallback onPressed}) {
  return FilledButton(
    onPressed: action.run == null ? null : onPressed,
    style: action.primary
        ? null
        : FilledButton.styleFrom(
            backgroundColor: AppColors.sand,
            foregroundColor: AppColors.text,
          ),
    child: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

String _subtitle(PsychologistProfile psy) {
  final parts = <String>[
    psy.specialty,
    if (psy.city != null && psy.city!.trim().isNotEmpty) psy.city!.trim(),
    if (psy.yearsOfExperience != null)
      '${psy.yearsOfExperience} an${psy.yearsOfExperience! > 1 ? 's' : ''}',
  ];
  return parts.join(' · ');
}

class _PsychologistCard extends StatelessWidget {
  const _PsychologistCard({
    required this.psychologist,
    required this.busy,
    required this.actions,
    required this.onTap,
  });

  final PsychologistProfile psychologist;
  final bool busy;
  final List<_CardAction> actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final psy = psychologist;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppAvatar(name: psy.fullName, size: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          psy.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          _subtitle(psy),
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (psy.rejected)
                    const _SolidLabel('Refusé', AppColors.danger)
                  else if (psy.profileVerified)
                    const _SolidLabel('Vérifié', AppColors.teal)
                  else
                    const Icon(Icons.chevron_right,
                        color: AppColors.muted, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              if (busy)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _actionButton(actions[i],
                            onPressed: () => actions[i].run?.call()),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolidLabel extends StatelessWidget {
  const _SolidLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Fiche détail d'un psychologue : bio, langues, licence, tarif,
// date d'inscription et justificatif si disponible.
class _PsychologistDetailPage extends StatefulWidget {
  const _PsychologistDetailPage({
    required this.psychologist,
    required this.adminService,
    required this.actions,
  });

  final PsychologistProfile psychologist;
  final AdminService adminService;
  final List<_CardAction> actions;

  @override
  State<_PsychologistDetailPage> createState() =>
      _PsychologistDetailPageState();
}

class _PsychologistDetailPageState extends State<_PsychologistDetailPage> {
  bool _openingDocument = false;
  String? _documentError;
  bool _acting = false;

  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  Future<void> _openLicenseDocument() async {
    setState(() {
      _openingDocument = true;
      _documentError = null;
    });
    try {
      final file = await widget.adminService
          .downloadLicenseDocument(widget.psychologist.id);
      final extension = file.contentType.contains('pdf')
          ? 'pdf'
          : file.contentType.contains('png')
              ? 'png'
              : 'jpg';
      final dir = await getTemporaryDirectory();
      final localFile = File(
        '${dir.path}/justificatif_${widget.psychologist.id}.$extension',
      );
      await localFile.writeAsBytes(file.bytes, flush: true);
      await OpenFilex.open(localFile.path);
    } catch (_) {
      setState(() => _documentError = "Impossible d'ouvrir le justificatif.");
    } finally {
      if (mounted) setState(() => _openingDocument = false);
    }
  }

  Future<void> _run(_CardAction action) async {
    final run = action.run;
    if (run == null) return;
    setState(() => _acting = true);
    await run();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final psy = widget.psychologist;
    final created = psy.createdAt;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                AppAvatar(name: psy.fullName, size: 70),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        psy.fullName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        psy.specialty,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      psy.rejected
                          ? const _SolidLabel('Refusé', AppColors.danger)
                          : psy.profileVerified
                              ? const _SolidLabel('Vérifié', AppColors.teal)
                              : const _SolidLabel(
                                  'En attente', AppColors.goldDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _DetailRow(label: 'Ville', value: psy.city),
          _DetailRow(
            label: 'Expérience',
            value: psy.yearsOfExperience != null
                ? '${psy.yearsOfExperience} an'
                    '${psy.yearsOfExperience! > 1 ? 's' : ''}'
                : null,
          ),
          _DetailRow(
            label: 'Prix d\'une séance',
            value: psy.consultationPrice != null
                ? '${formatPrice(psy.consultationPrice!)} F'
                : null,
          ),
          _DetailRow(label: 'Langues', value: psy.languages),
          _DetailRow(label: 'Licence', value: psy.licenseNumber),
          _DetailRow(
            label: 'Inscrit le',
            value: created != null
                ? '${created.day} ${_months[created.month - 1]} ${created.year}'
                : null,
          ),
          if (psy.bio != null && psy.bio!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: Text(
                '« ${psy.bio!.trim()} »',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: AppColors.text,
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 4, 6),
            child: Text(
              'Justificatif',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          if (psy.hasLicenseDocument)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _openingDocument ? null : _openLicenseDocument,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.text,
                ),
                icon: _openingDocument
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.description_outlined, size: 20),
                label: const Text('Voir le justificatif'),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Aucun justificatif fourni',
                style: TextStyle(fontSize: 16, color: AppColors.muted),
              ),
            ),
          if (_documentError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                _documentError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 14),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: _acting
              ? const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Row(
                  children: [
                    for (var i = 0; i < widget.actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _actionButton(widget.actions[i],
                            onPressed: () => _run(widget.actions[i])),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value!.trim(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
