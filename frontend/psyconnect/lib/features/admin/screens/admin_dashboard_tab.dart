import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';

// Onglet tableau de bord administrateur : KPIs, validations en attente et
// répartition des séances par type. Ces données sont calculées côté client
// depuis la liste des RDV, aucun endpoint dédié n'existe pour l'instant.
class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key, required this.onSeeAllValidations});

  final VoidCallback onSeeAllValidations;

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final _adminService = AdminService();

  bool _loading = true;
  String? _error;
  AdminProfileStats? _profileStats;
  List<PsychologistProfile> _pendingPsychologists = [];
  List<Appointment> _appointments = [];
  String? _busyPsychologistAction;

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
      final results = await Future.wait([
        _adminService.getProfileStats(),
        _adminService.listPsychologists(),
        _adminService.listAppointments(),
      ]);
      if (!mounted) return;
      final psychologists = results[1] as List<PsychologistProfile>;
      setState(() {
        _profileStats = results[0] as AdminProfileStats;
        _pendingPsychologists = psychologists
            .where((p) => !p.profileVerified && !p.rejected)
            .toList();
        _appointments = results[2] as List<Appointment>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Impossible de charger le dashboard. Vérifiez que l'API "
            'Gateway et les services auth/user/appointment tournent.';
        _loading = false;
      });
    }
  }

  Future<void> _setVerified(PsychologistProfile psy, bool verified) async {
    setState(() => _busyPsychologistAction = '${psy.id}');
    try {
      await _adminService.setPsychologistVerified(psy.id, verified);
      if (!mounted) return;
      setState(() {
        _pendingPsychologists =
            _pendingPsychologists.where((p) => p.id != psy.id).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible pour le moment.')),
      );
    } finally {
      if (mounted) setState(() => _busyPsychologistAction = null);
    }
  }

  // Distinct de _setVerified : passer verified=false ne retire pas la demande
  // de la liste (un profil en attente a déjà verified=false). Il faut passer
  // par l'endpoint rejected pour marquer explicitement le refus.
  Future<void> _reject(PsychologistProfile psy) async {
    setState(() => _busyPsychologistAction = '${psy.id}');
    try {
      await _adminService.setPsychologistRejected(psy.id, true);
      if (!mounted) return;
      setState(() {
        _pendingPsychologists =
            _pendingPsychologists.where((p) => p.id != psy.id).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible pour le moment.')),
      );
    } finally {
      if (mounted) setState(() => _busyPsychologistAction = null);
    }
  }

  int get _appointmentsThisMonth {
    final now = DateTime.now();
    return _appointments
        .where((a) =>
            a.startTime.year == now.year && a.startTime.month == now.month)
        .length;
  }

  // Répartition en pourcentage par type de consultation, calculée côté client.
  Map<ConsultationType, double> get _typeBreakdown {
    if (_appointments.isEmpty) return {};
    final counts = <ConsultationType, int>{};
    for (final a in _appointments) {
      counts[a.consultationType] = (counts[a.consultationType] ?? 0) + 1;
    }
    return counts.map((k, v) => MapEntry(k, v / _appointments.length));
  }

  @override
  Widget build(BuildContext context) {
    final pseudo = context.watch<AuthProvider>().session?.pseudo ?? '';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 100),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style:
                                        const TextStyle(color: AppColors.muted)),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                    onPressed: _load,
                                    child: const Text('Réessayer')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: AppColors.headerGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Administration',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              'PsyConnect Sénégal · Connecté en tant que $pseudo',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _Kpi(
                              value: '${_profileStats?.totalPatients ?? 0}',
                              label: 'Patients actifs',
                              color: AppColors.teal),
                          const SizedBox(width: 10),
                          _Kpi(
                              value:
                                  '${_profileStats?.verifiedPsychologists ?? 0}',
                              label: 'Psys vérifiés',
                              color: AppColors.gold),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _Kpi(
                              value:
                                  '${_profileStats?.pendingPsychologists ?? 0}',
                              label: 'En attente',
                              color: AppColors.rose),
                          const SizedBox(width: 10),
                          _Kpi(
                              value: '$_appointmentsThisMonth',
                              label: 'Séances / mois',
                              color: AppColors.tealDark),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Validations en attente',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          if (_pendingPsychologists.isNotEmpty)
                            TextButton(
                              onPressed: widget.onSeeAllValidations,
                              child: const Text('Voir tout'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_pendingPsychologists.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.tealMid),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: AppColors.teal),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Aucun psychologue en attente de validation.',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final psy in _pendingPsychologists.take(3)) ...[
                          _ValidationCard(
                            psychologist: psy,
                            busy: _busyPsychologistAction == '${psy.id}',
                            onAccept: () => _setVerified(psy, true),
                            onReject: () => _reject(psy),
                          ),
                          const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 22),
                      if (_typeBreakdown.isNotEmpty) ...[
                        const Text('Séances par type',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.tealMid),
                          ),
                          child: Column(
                            children: [
                              for (final type in ConsultationType.values)
                                if (_typeBreakdown[type] != null)
                                  _TypeBar(
                                    label: type.label,
                                    ratio: _typeBreakdown[type]!,
                                    color: _colorForType(type),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Color _colorForType(ConsultationType type) {
    switch (type) {
      case ConsultationType.video:
        return AppColors.teal;
      case ConsultationType.audio:
        return AppColors.gold;
      case ConsultationType.physical:
        return AppColors.rose;
      case ConsultationType.chat:
        return AppColors.tealDark;
    }
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 20, color: color)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({
    required this.psychologist,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final PsychologistProfile psychologist;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      '${psychologist.city != null ? ' · ${psychologist.city}' : ''}',
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (busy)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        minimumSize: const Size.fromHeight(38)),
                    child: const Text('Accepter'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rose,
                        side: const BorderSide(color: AppColors.rose),
                        minimumSize: const Size.fromHeight(38)),
                    child: const Text('Refuser'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TypeBar extends StatelessWidget {
  const _TypeBar({required this.label, required this.ratio, required this.color});

  final String label;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Text('$pct%',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.scaffoldOuter,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
