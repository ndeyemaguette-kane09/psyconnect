import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/services/appointment_service.dart';
import '../../patient/services/psychologist_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/services/payment_service.dart';
import 'psy_transaction_history_screen.dart';
import 'psychologist_profile_screen.dart';

// Onglet Statistiques côté psychologue. Les compteurs de rendez-vous sont
// calculés depuis la liste locale ; le revenu est fourni par un endpoint dédié.
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
  // Revenu et portefeuille chargés séparément : en cas d'échec, seul "—" s'affiche.
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

    // Revenu et portefeuille chargés séparément : une erreur de l'un
    // n'empêche pas l'affichage de l'autre (ex : table de retraits absente
    // en développement — le portefeuille échoue mais le revenu s'affiche).
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

  Future<void> _showWithdrawDialog(int psychologistId) async {
    final amountCtrl = TextEditingController();
    WithdrawalMethod selectedMethod = WithdrawalMethod.orangeMoney;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Retirer mes fonds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_wallet != null) ...[
                Text(
                  'Solde disponible : ${_formatXof(_wallet!.availableBalance)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.tealDark),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<WithdrawalMethod>(
                value: selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Méthode',
                  border: OutlineInputBorder(),
                ),
                items: WithdrawalMethod.values
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.label),
                        ))
                    .toList(),
                onChanged: (m) {
                  if (m != null) setDState(() => selectedMethod = m);
                },
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 10),
                Text(dialogError!,
                    style: const TextStyle(color: AppColors.rose, fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final amountStr = amountCtrl.text.trim();
                if (amountStr.isEmpty) {
                  setDState(() => dialogError = 'Entrez un montant.');
                  return;
                }
                final amount = double.tryParse(amountStr);
                if (amount == null || amount <= 0) {
                  setDState(
                      () => dialogError = 'Montant invalide.');
                  return;
                }
                if (_wallet != null && amount > _wallet!.availableBalance) {
                  setDState(() =>
                      dialogError = 'Solde insuffisant.');
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await _paymentService.withdraw(
                    psychologistId: psychologistId,
                    amount: amount,
                    method: selectedMethod,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${_formatXof(amount)} retirés vers ${selectedMethod.label}'),
                      backgroundColor: AppColors.teal,
                    ),
                  );
                  _load(); // recharge le solde mis à jour
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur : $e'),
                      backgroundColor: AppColors.rose,
                    ),
                  );
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  int _countByStatus(AppointmentStatus status) =>
      _appointments.where((a) => a.status == status).length;

  // Même format que l'onglet admin, sans factorisation supplémentaire.
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
                // Accès au profil psy (pas de 6e onglet dédié).
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
              // Le portefeuille est affiché dans un état dégradé si les données sont indisponibles.
              if (_wallet != null)
                _WalletCard(
                  wallet: _wallet!,
                  formatXof: _formatXof,
                  onWithdraw: () => _showWithdrawDialog(
                    context.read<AuthProvider>().session!.profileId!,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.tealMid),
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

// Affiche le revenu net (après commission) pour éviter toute confusion
// sur le montant réellement perçu. Le taux est rappelé en sous-titre.
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
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
      ],
    );
  }
}

// carte portefeuille : solde disponible + bouton retrait + historique des retraits
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tealMid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // en-tête
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // solde disponible mis en avant
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

          // détail en deux colonnes
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

          // historique (toggle)
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
