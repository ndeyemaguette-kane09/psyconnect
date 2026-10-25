import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../patient/models/appointment_models.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'admin_appointments_list_screen.dart';
import 'admin_payments_list_screen.dart';

// onglet "Stats", vue globale RDV + paiements, via
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
    return buffer.toString();
  }

  void _openAppointments(BuildContext context, AppointmentStatus status) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminAppointmentsListScreen(initialStatus: status),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          children: [
            Text(
              'Statistiques',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 22),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null || stats == null)
              AppErrorState(
                message: _error ?? 'Aucune donnée.',
                onRetry: _load,
              )
            else ...[
              const Text(
                'Revenu total encaissé',
                style: TextStyle(fontSize: 16, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: _formatXof(stats.totalRevenue)),
                    const TextSpan(
                      text: ' F CFA',
                      style: TextStyle(
                        fontSize: 22,
                        color: AppColors.muted,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.05,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${stats.completedPayments} paiement'
                '${stats.completedPayments > 1 ? 's' : ''} réussi'
                '${stats.completedPayments > 1 ? 's' : ''} sur '
                '${stats.totalPayments}',
                style: const TextStyle(fontSize: 15, color: AppColors.muted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _push(const AdminPaymentsListScreen()),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  child: const Text(
                    'Voir les paiements',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // part de revenus de l'admin, taux reglable depuis l'onglet
              // Config, pas une valeur figee en dur
              const _Heading('Qui touche quoi'),
              _Bar(parts: [
                _Part(stats.platformRevenue, AppColors.gold),
                _Part(stats.psychologistRevenue, AppColors.teal),
              ]),
              const SizedBox(height: 10),
              _LegendRow(
                color: AppColors.gold,
                label: 'PsyConnect · commission '
                    '${stats.commissionRatePercent.toStringAsFixed(0)} %',
                value: '${_formatXof(stats.platformRevenue)} F',
              ),
              _LegendRow(
                color: AppColors.teal,
                label: 'Psychologues',
                value: '${_formatXof(stats.psychologistRevenue)} F',
              ),
              const SizedBox(height: 28),
              InkWell(
                onTap: () => _push(const AdminAppointmentsListScreen()),
                child: _Heading(
                  '${stats.totalAppointments} rendez-vous au total',
                  trailing: true,
                ),
              ),
              _Bar(parts: [
                _Part(stats.pendingAppointments.toDouble(), AppColors.gold),
                _Part(stats.confirmedAppointments.toDouble(), AppColors.teal),
                _Part(stats.completedAppointments.toDouble(), AppColors.faint),
                _Part(stats.cancelledAppointments.toDouble(), AppColors.muted),
                _Part(stats.rejectedAppointments.toDouble(), AppColors.rose),
              ]),
              const SizedBox(height: 10),
              _LegendRow(
                color: AppColors.gold,
                label: 'En attente',
                value: '${stats.pendingAppointments}',
                onTap: () =>
                    _openAppointments(context, AppointmentStatus.pending),
              ),
              _LegendRow(
                color: AppColors.teal,
                label: 'Confirmés',
                value: '${stats.confirmedAppointments}',
                onTap: () =>
                    _openAppointments(context, AppointmentStatus.confirmed),
              ),
              _LegendRow(
                color: AppColors.faint,
                label: 'Terminés',
                value: '${stats.completedAppointments}',
                onTap: () =>
                    _openAppointments(context, AppointmentStatus.completed),
              ),
              _LegendRow(
                color: AppColors.muted,
                label: 'Annulés',
                value: '${stats.cancelledAppointments}',
                onTap: () =>
                    _openAppointments(context, AppointmentStatus.cancelled),
              ),
              _LegendRow(
                color: AppColors.rose,
                label: 'Refusés',
                value: '${stats.rejectedAppointments}',
                onTap: () =>
                    _openAppointments(context, AppointmentStatus.rejected),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.trailing = false});

  final String title;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          if (trailing)
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 22),
        ],
      ),
    );
  }
}

class _Part {
  const _Part(this.value, this.color);

  final double value;
  final Color color;
}

class _Bar extends StatelessWidget {
  const _Bar({required this.parts});

  final List<_Part> parts;

  @override
  Widget build(BuildContext context) {
    final visible = parts.where((p) => p.value > 0).toList();
    if (visible.isEmpty) {
      return Container(
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.sand,
          borderRadius: BorderRadius.circular(7),
        ),
      );
    }
    return SizedBox(
      height: 14,
      child: Row(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: (visible[i].value * 100).round().clamp(1, 1 << 30),
              child: Container(
                decoration: BoxDecoration(
                  color: visible[i].color,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, color: AppColors.text),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.muted),
            ],
          ],
        ),
      ),
    );
  }
}
