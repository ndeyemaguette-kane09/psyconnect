import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../patient/models/appointment_models.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'admin_appointments_list_screen.dart';
import 'admin_payments_list_screen.dart';

// onglet "Stats" — vue globale RDV + paiements, via
// GET /admin/stats/appointments : statuts + agregats deja calcules cote
// backend, contrairement au Dashboard qui derive tout cote client
class AdminStatsTab extends StatefulWidget {
  const AdminStatsTab({super.key});

  @override
  State<AdminStatsTab> createState() => _AdminStatsTabState();
}

class _AdminStatsTabState extends State<AdminStatsTab> {
  final _adminService = AdminService();

  bool _loading = true;
  String? _error;
  AdminAppointmentStats? _stats;

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
      final stats = await _adminService.getAppointmentStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les statistiques.';
        _loading = false;
      });
    }
  }

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

  void _openAppointments(BuildContext context, AppointmentStatus status) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminAppointmentsListScreen(initialStatus: status),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('Statistiques', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null || stats == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(_error ?? 'Aucune donnée.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                    ],
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  _StatBox(
                    value: '${stats.totalAppointments}',
                    label: 'RDV au total',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminAppointmentsListScreen(),
                      ),
                    ),
                  ),
                  _StatBox(
                    value: '${stats.totalPayments}',
                    label: 'Paiements',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminPaymentsListScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revenu total (paiements réussis)',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_formatXof(stats.totalRevenue),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${stats.completedPayments} paiement(s) réussi(s) sur ${stats.totalPayments}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // part de revenus de l'admin — taux reglable depuis l'onglet
              // Config, pas une valeur figee en dur
              SizedBox(
                width: double.infinity,
                child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                borderColor: AppColors.tealMid,
                shadow: const [],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Répartition du revenu',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('Commission : ${stats.commissionRatePercent.toStringAsFixed(0)}%',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _RevenueShare(
                            label: 'Plateforme (vous)',
                            value: _formatXof(stats.platformRevenue),
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _RevenueShare(
                            label: 'Psychologues',
                            value: _formatXof(stats.psychologistRevenue),
                            color: AppColors.tealDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 24),
              Text('Répartition des rendez-vous',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _StatusRow(
                  label: 'En attente',
                  count: stats.pendingAppointments,
                  color: AppColors.gold,
                  onTap: () => _openAppointments(context, AppointmentStatus.pending)),
              _StatusRow(
                  label: 'Confirmés',
                  count: stats.confirmedAppointments,
                  color: AppColors.teal,
                  onTap: () => _openAppointments(context, AppointmentStatus.confirmed)),
              _StatusRow(
                  label: 'Terminés',
                  count: stats.completedAppointments,
                  color: AppColors.tealDark,
                  onTap: () => _openAppointments(context, AppointmentStatus.completed)),
              _StatusRow(
                  label: 'Annulés',
                  count: stats.cancelledAppointments,
                  color: AppColors.muted,
                  onTap: () => _openAppointments(context, AppointmentStatus.cancelled)),
              _StatusRow(
                  label: 'Refusés',
                  count: stats.rejectedAppointments,
                  color: AppColors.rose,
                  onTap: () => _openAppointments(context, AppointmentStatus.rejected)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        onTap: onTap,
        borderColor: AppColors.tealMid,
        shadow: const [],
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: AppSpacing.sm),
        child: Column(
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.tealDark)),
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

class _RevenueShare extends StatelessWidget {
  const _RevenueShare({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
              Text('$count', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
