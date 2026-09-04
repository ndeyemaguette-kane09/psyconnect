import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../patient/models/psychologist_models.dart';
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.muted)),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                  onPressed: _load, child: const Text('Réessayer')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Text('Validation', style: Theme.of(context).textTheme.displayMedium),
                      const SizedBox(height: 16),
                      Text('En attente (${_pending.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      if (_pending.isEmpty)
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          borderColor: AppColors.tealMid,
                          shadow: const [],
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: AppColors.teal),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text('Aucune demande en attente.',
                                    style: TextStyle(color: AppColors.muted)),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._buildPaginatedSection(
                          items: _pending,
                          page: _pendingPage,
                          onPageChanged: (p) => setState(() => _pendingPage = p),
                          actionsFor: (psy) => [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _setVerified(psy, true),
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.teal,
                                    minimumSize: const Size.fromHeight(38)),
                                child: const Text('Accepter'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _setRejected(psy, true),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.rose,
                                    side: const BorderSide(color: AppColors.rose),
                                    minimumSize: const Size.fromHeight(38)),
                                child: const Text('Refuser'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      Text('Refusés (${_rejected.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      if (_rejected.isEmpty)
                        const Text('Aucune demande refusée pour le moment.',
                            style: TextStyle(color: AppColors.muted))
                      else
                        ..._buildPaginatedSection(
                          items: _rejected,
                          page: _rejectedPage,
                          onPageChanged: (p) => setState(() => _rejectedPage = p),
                          actionsFor: (psy) => [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _setRejected(psy, false),
                                icon: const Icon(Icons.undo, size: 16),
                                label: const Text('Remettre en attente'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.muted,
                                  minimumSize: const Size.fromHeight(38),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _setVerified(psy, true),
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.teal,
                                    minimumSize: const Size.fromHeight(38)),
                                child: const Text('Accepter'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      Text('Vérifiés (${_verified.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      if (_verified.isEmpty)
                        const Text('Aucun psychologue vérifié pour le moment.',
                            style: TextStyle(color: AppColors.muted))
                      else
                        ..._buildPaginatedSection(
                          items: _verified,
                          page: _verifiedPage,
                          onPageChanged: (p) => setState(() => _verifiedPage = p),
                          actionsFor: (psy) => [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _setVerified(psy, false),
                                icon: const Icon(Icons.undo, size: 16),
                                label: const Text('Retirer la vérification'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.muted,
                                  minimumSize: const Size.fromHeight(38),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
      ),
    );
  }

  // Construit les cartes paginées d'une section et la barre de navigation,
  // avec les boutons d'action spécifiques à chaque section (actionsFor).
  List<Widget> _buildPaginatedSection({
    required List<PsychologistProfile> items,
    required int page,
    required ValueChanged<int> onPageChanged,
    required List<Widget> Function(PsychologistProfile psy) actionsFor,
  }) {
    final pageCount = pageCountFor(items.length, _pageSize);
    final pageItems = paginate(items, page, _pageSize);
    return [
      for (final psy in pageItems) ...[
        _PsychologistCard(
          psychologist: psy,
          busy: _busyId == '${psy.id}',
          actions: actionsFor(psy),
          onTap: () => _showDetail(psy),
        ),
        const SizedBox(height: 10),
      ],
      PageControls(page: page, pageCount: pageCount, onPageChanged: onPageChanged),
    ];
  }

  // Ouvre la fiche détail avant de prendre une décision : tous les champs
  // du profil et le justificatif si fourni.
  void _showDetail(PsychologistProfile psy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PsychologistDetailSheet(
        psychologist: psy,
        adminService: _adminService,
      ),
    );
  }
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
  final List<Widget> actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.tealMid),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.tealLight,
                    child: Icon(Icons.person, color: AppColors.tealDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(psychologist.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          '${psychologist.specialty}'
                          '${psychologist.city != null ? ' · ${psychologist.city}' : ''}'
                          '${psychologist.yearsOfExperience != null ? ' · ${psychologist.yearsOfExperience} ans d\'exp.' : ''}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (psychologist.profileVerified)
                    const Icon(Icons.verified, color: AppColors.teal, size: 20)
                  else if (psychologist.rejected)
                    const Icon(Icons.block, color: AppColors.rose, size: 20),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(children: actions),
          ),
        ],
      ),
    );
  }
}

// Feuille de détail d'un psychologue : bio, langues, licence, tarif,
// date d'inscription et justificatif si disponible.
class _PsychologistDetailSheet extends StatefulWidget {
  const _PsychologistDetailSheet({
    required this.psychologist,
    required this.adminService,
  });

  final PsychologistProfile psychologist;
  final AdminService adminService;

  @override
  State<_PsychologistDetailSheet> createState() =>
      _PsychologistDetailSheetState();
}

class _PsychologistDetailSheetState extends State<_PsychologistDetailSheet> {
  bool _openingDocument = false;
  String? _documentError;

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

  @override
  Widget build(BuildContext context) {
    final psy = widget.psychologist;
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.tealMid,
                  ),
                ),
              ),
              Text(psy.fullName,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(psy.specialty,
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              _DetailRow(label: 'Ville', value: psy.city),
              _DetailRow(
                label: "Années d'expérience",
                value: psy.yearsOfExperience?.toString(),
              ),
              _DetailRow(
                label: 'Prix consultation',
                value: psy.consultationPrice != null
                    ? '${psy.consultationPrice} FCFA'
                    : null,
              ),
              _DetailRow(label: 'Langues parlées', value: psy.languages),
              _DetailRow(
                label: 'Numéro de licence',
                value: psy.licenseNumber,
              ),
              _DetailRow(
                label: "Date d'inscription",
                value: psy.createdAt != null
                    ? '${psy.createdAt!.day.toString().padLeft(2, '0')}/'
                        '${psy.createdAt!.month.toString().padLeft(2, '0')}/'
                        '${psy.createdAt!.year}'
                    : null,
              ),
              if (psy.bio != null && psy.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Bio',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(psy.bio!, style: const TextStyle(color: AppColors.muted)),
              ],
              const SizedBox(height: 20),
              if (psy.hasLicenseDocument)
                OutlinedButton.icon(
                  onPressed: _openingDocument ? null : _openLicenseDocument,
                  icon: _openingDocument
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.description_outlined),
                  label: const Text('Voir le justificatif'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                )
              else
                const Text(
                  'Aucun justificatif fourni.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              if (_documentError != null) ...[
                const SizedBox(height: 8),
                Text(_documentError!,
                    style: const TextStyle(color: AppColors.rose, fontSize: 12)),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value!,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
