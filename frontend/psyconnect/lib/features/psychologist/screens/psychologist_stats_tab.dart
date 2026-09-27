import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/services/appointment_service.dart';
import '../../patient/services/psychologist_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/screens/psy_wallet_screen.dart';
import '../../payment/services/payment_service.dart';
import 'psy_transaction_history_screen.dart';
import 'psychologist_profile_screen.dart';

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
  PsychologistRevenue? _revenue;
  PsychologistWallet? _wallet;

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
      final revenue = await _paymentService.getPsychologistRevenue(psychologistId);
      if (!mounted) return;
      setState(() => _revenue = revenue);
    } catch (_) {}

    try {
      final wallet = await _paymentService.getPsychologistWallet(psychologistId);
      if (!mounted) return;
      setState(() => _wallet = wallet);
    } catch (_) {}
  }

  Future<void> _openWallet() async {
    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PsyWalletScreen(psychologistId: psychologistId),
      ),
    );
    if (mounted) _load();
  }

  int _countByStatus(AppointmentStatus status) =>
      _appointments.where((a) => a.status == status).length;

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
                IconButton(
                  tooltip: 'Mon profil',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PsychologistProfileScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.account_circle_outlined,
                      color: AppColors.tealDark, size: 34),
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
              const SectionHeader(title: 'Mon activité'),
              const SizedBox(height: 6),
              StatBand(
                children: [
                  StatTile(
                    value: '${_appointments.length}',
                    label: 'RDV au total',
                  ),
                  StatTile(
                    value:
                        '${_appointments.map((a) => a.patientId).toSet().length}',
                    label: 'Patients suivis',
                  ),
                  StatTile(
                    value: _me?.rating != null && _me!.rating! > 0
                        ? _me!.rating!.toStringAsFixed(1)
                        : '—',
                    label: 'Note moyenne',
                  ),
                  StatTile(
                    value: '${_me?.totalReviews ?? 0}',
                    label: 'Avis reçus',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_revenue != null) ...[
                _RevenueCard(
                  revenue: _revenue!,
                  formatXof: _formatXof,
                  onViewTransactions: () {
                    final psychologistId =
                        context.read<AuthProvider>().session?.profileId;
                    if (psychologistId == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PsyTransactionHistoryScreen(
                          psychologistId: psychologistId,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (_wallet != null)
                _WalletCard(
                  wallet: _wallet!,
                  formatXof: _formatXof,
                  onWithdraw: () => _openWallet(),
                )
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: AppColors.muted, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Portefeuille',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted)),
                            SizedBox(height: 4),
                            Text(
                              'Données indisponibles.\nVérifiez que la base de données est à jour.',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                          onPressed: _load,
                          child: const Text('Rafraîchir')),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Répartition des rendez-vous'),
              const SizedBox(height: 4),
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

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.revenue,
    required this.formatXof,
    required this.onViewTransactions,
  });

  final PsychologistRevenue revenue;
  final String Function(double) formatXof;
  final VoidCallback onViewTransactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      color: AppColors.tealDark,
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onViewTransactions,
              icon: const Icon(Icons.receipt_long_outlined,
                  size: 16, color: Colors.white70),
              label: const Text(
                'Voir le détail',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
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
        Text(
          value,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontSize: 20,
                height: 1,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _WalletCard extends StatefulWidget {
  const _WalletCard({
    required this.wallet,
    required this.formatXof,
    required this.onWithdraw,
  });

  final PsychologistWallet wallet;
  final String Function(double) formatXof;
  final VoidCallback onWithdraw;

  @override
  State<_WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<_WalletCard> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.tealDark, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Portefeuille',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealDark,
                        fontSize: 15),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: wallet.availableBalance <= 0 ? null : widget.onWithdraw,
                icon: const Icon(Icons.arrow_circle_down_outlined, size: 18),
                label: const Text('Retirer'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            widget.formatXof(wallet.availableBalance),
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.tealDark),
          ),
          const Text('Solde disponible',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),

          Row(
            children: [
              _WalletStat(
                label: 'Revenu net total',
                value: widget.formatXof(wallet.totalNetRevenue),
              ),
              _WalletStat(
                label: 'Déjà retiré',
                value: widget.formatXof(wallet.totalWithdrawn),
              ),
            ],
          ),

          if (wallet.withdrawals.isNotEmpty) ...[
            const Divider(height: 24),
            GestureDetector(
              onTap: () => setState(() => _showHistory = !_showHistory),
              child: Row(
                children: [
                  Text(
                    'Historique (${wallet.withdrawals.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.tealDark,
                        fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(
                    _showHistory ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.tealDark,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_showHistory) ...[
              const SizedBox(height: 8),
              ...wallet.withdrawals.map(
                (w) => _WithdrawalRow(
                    withdrawal: w, formatXof: widget.formatXof),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _WithdrawalRow extends StatelessWidget {
  const _WithdrawalRow({required this.withdrawal, required this.formatXof});

  final PsychologistWithdrawal withdrawal;
  final String Function(double) formatXof;

  String _methodLabel(String method) {
    switch (method) {
      case 'ORANGE_MONEY':
        return 'Orange Money';
      case 'WAVE':
        return 'Wave';
      case 'BANK_TRANSFER':
        return 'Virement';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = withdrawal.createdAt;
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.teal, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_methodLabel(withdrawal.method),
                    style: const TextStyle(fontSize: 13)),
                Text(date,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '- ${formatXof(withdrawal.amount)}',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.rose,
                fontSize: 13),
          ),
        ],
      ),
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13.5)),
            ),
            Text(
              '$count',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontSize: 17, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

