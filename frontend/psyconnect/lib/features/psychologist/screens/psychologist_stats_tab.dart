import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/services/appointment_service.dart';
import '../../patient/services/psychologist_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/services/payment_service.dart';
import 'psychologist_profile_screen.dart';

/// Contenu de l'onglet "Stats" du parcours psychologue (cf. maquette v2).
///
/// Aucun endpoint de statistiques agrégées n'existe côté backend pour les
/// compteurs RDV (vérifié : aucun service auth/user/appointment/notification/
/// ml n'en expose) : ils sont calculés côté client à partir de
/// `GET /appointments/psychologist/{id}`. Le revenu, lui, vient d'un
/// endpoint dédié (`GET /payments/psychologist/{id}/revenue`) pour ne pas
/// recalculer la commission côté Flutter.
class PsychologistStatsTab extends StatefulWidget {
  const PsychologistStatsTab({super.key});

  @override
  State<PsychologistStatsTab> createState() => _PsychologistStatsTabState();
}

class _PsychologistStatsTabState extends State<PsychologistStatsTab> {
  final _appointmentService = AppointmentService();
  final _psychologistService = PsychologistService();
  final _paymentService = PaymentService();

  bool _loading = true;
  String? _error;
  PsychologistProfile? _me;
  List<Appointment> _appointments = [];
  // Revenu : chargé séparément des autres stats, avec son propre statut
  // d'erreur. Un psychologue sans paiement reçu (ou un souci réseau ponctuel
  // sur cet appel précis) ne doit pas empêcher l'affichage du reste de
  // l'écran — on affiche juste "—" pour le revenu dans ce cas.
  PsychologistRevenue? _revenue;

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

    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) {
      setState(() {
        _error = 'Profil psychologue introuvable.';
        _loading = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        _psychologistService.getPsychologistById(psychologistId),
        _appointmentService.getAppointmentsByPsychologistId(psychologistId),
      ]);
      if (!mounted) return;
      setState(() {
        _me = results[0] as PsychologistProfile;
        _appointments = results[1] as List<Appointment>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les statistiques.';
        _loading = false;
      });
      return;
    }

    try {
      final revenue = await _paymentService.getPsychologistRevenue(
        psychologistId,
      );
      if (!mounted) return;
      setState(() => _revenue = revenue);
    } catch (e) {
      // Pas de _error ici, cf. commentaire sur le champ _revenue.
    }
  }

  int _countByStatus(AppointmentStatus status) =>
      _appointments.where((a) => a.status == status).length;

  /// Même format que AdminStatsTab._formatXof (pas de helper partagé dans
  /// le projet pour un calcul aussi court).
  String _formatXof(double amount) {
    final rounded = amount.round();
    final digits = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '$buffer FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Statistiques',
                    style: Theme.of(context).textTheme.displayMedium),
                // Pas de 6e onglet "Profil" (la nav suit la maquette à 5
                // items) : on accède au profil + à la déconnexion via ce
                // bouton.
                IconButton(
                  tooltip: 'Mon profil',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PsychologistProfileScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.account_circle_outlined,
                      color: AppColors.tealDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
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
              )
            else ...[
              Row(
                children: [
                  _StatBox(
                      value: '${_appointments.length}',
                      label: 'RDV au total'),
                  _StatBox(
                      value:
                          '${_appointments.map((a) => a.patientId).toSet().length}',
                      label: 'Patients suivis'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatBox(
                      value: _me?.rating != null && _me!.rating! > 0
                          ? _me!.rating!.toStringAsFixed(1)
                          : '—',
                      label: 'Note moyenne'),
                  _StatBox(
                      value: '${_me?.totalReviews ?? 0}', label: "Avis reçus"),
                ],
              ),
              const SizedBox(height: 24),
              if (_revenue != null) ...[
                _RevenueCard(revenue: _revenue!, formatXof: _formatXof),
                const SizedBox(height: 24),
              ],
              Text('Répartition des rendez-vous',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _StatusRow(
                  label: 'En attente',
                  count: _countByStatus(AppointmentStatus.pending),
                  color: AppColors.gold),
              _StatusRow(
                  label: 'Confirmés',
                  count: _countByStatus(AppointmentStatus.confirmed),
                  color: AppColors.teal),
              _StatusRow(
                  label: 'Terminés',
                  count: _countByStatus(AppointmentStatus.completed),
                  color: AppColors.muted),
              _StatusRow(
                  label: 'Annulés/refusés',
                  count: _countByStatus(AppointmentStatus.cancelled) +
                      _countByStatus(AppointmentStatus.rejected),
                  color: AppColors.rose),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.tealDark)),
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

/// Affiche le revenu NET (après commission) du psychologue plutôt que le
/// brut, pour ne pas afficher un montant que le psychologue ne touchera
/// jamais en totalité. Le taux de
/// commission est affiché en sous-titre pour expliquer l'écart avec ce que
/// les patients ont réellement payé.
class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.revenue, required this.formatXof});

  final PsychologistRevenue revenue;
  final String Function(double) formatXof;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.tealDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Revenu net',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Text(
                'Commission ${revenue.commissionRatePercent.toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RevenueValue(
                  label: 'Ce mois-ci',
                  value: formatXof(revenue.currentMonthNetRevenue),
                ),
              ),
              Expanded(
                child: _RevenueValue(
                  label: 'Total',
                  value: formatXof(revenue.totalNetRevenue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueValue extends StatelessWidget {
  const _RevenueValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text('$count',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
