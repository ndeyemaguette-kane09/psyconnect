import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/services/profile_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/services/payment_service.dart';

// historique détaillé des paiements reçus par le psy.
// charge les transactions puis résout les pseudos patients en parallèle
// (appels GET /patients/{id} pour les patientId uniques de la liste).
class PsyTransactionHistoryScreen extends StatefulWidget {
  const PsyTransactionHistoryScreen({super.key, required this.psychologistId});

  final int psychologistId;

  @override
  State<PsyTransactionHistoryScreen> createState() =>
      _PsyTransactionHistoryScreenState();
}

class _PsyTransactionHistoryScreenState
    extends State<PsyTransactionHistoryScreen> {
  final _paymentService = PaymentService();
  final _profileService = ProfileService();

  bool _loading = true;
  String? _error;
  List<PaymentTransaction> _transactions = [];
  // patientId → label affiché (pseudo ou "Patient #X" si anonyme ou si erreur)
  Map<int, String> _patientLabels = {};

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
      final txns = await _paymentService
          .getTransactionsByPsychologistId(widget.psychologistId);

      // résolution des pseudos : un seul appel par patientId unique
      final uniqueIds =
          txns.map((t) => t.patientId).whereType<int>().toSet();
      final labelMap = <int, String>{};

      await Future.wait(
        uniqueIds.map((pid) async {
          try {
            final profile = await _profileService.getPatientProfileById(pid);
            if (profile.anonymousMode) {
              labelMap[pid] = 'Patient anonyme';
            } else {
              final initial = profile.lastName.isNotEmpty
                  ? ' ${profile.lastName[0].toUpperCase()}.'
                  : '';
              labelMap[pid] = '${profile.firstName}$initial';
            }
          } catch (_) {
            // si user-service ne répond pas pour ce patient, on garde l'id
            labelMap[pid] = 'Patient #$pid';
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _transactions = txns;
        _patientLabels = labelMap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les transactions.';
        _loading = false;
      });
    }
  }

  String _formatXof(double amount) {
    final rounded = amount.round();
    final digits = rounded.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return '$buf FCFA';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transactions',
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w700)),
            if (!_loading && _transactions.isNotEmpty)
              Text(
                '${_transactions.length} paiement${_transactions.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                              onPressed: _load,
                              child: const Text('Réessayer')),
                        ],
                      ),
                    ),
                  )
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: AppColors.tealLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 32,
                                  color: AppColors.teal),
                            ),
                            const SizedBox(height: 16),
                            const Text('Aucune transaction',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text(
                              'Les paiements reçus apparaîtront ici.',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: _transactions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final t = _transactions[i];
                            return _TransactionCard(
                              transaction: t,
                              patientLabel: t.patientId != null
                                  ? (_patientLabels[t.patientId!] ??
                                      'Patient #${t.patientId}')
                                  : '—',
                              formatXof: _formatXof,
                              formatDate: _formatDate,
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.patientLabel,
    required this.formatXof,
    required this.formatDate,
  });

  final PaymentTransaction transaction;
  final String patientLabel;
  final String Function(double) formatXof;
  final String Function(DateTime?) formatDate;

  bool get _isRefunded => transaction.status == PaymentStatus.refunded;

  @override
  Widget build(BuildContext context) {
    final color = _isRefunded ? AppColors.gold : AppColors.teal;
    final bgColor = _isRefunded ? AppColors.goldLight : AppColors.tealLight;
    final icon = _isRefunded
        ? Icons.undo_outlined
        : Icons.check_circle_outline;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // icône statut
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),

            // infos principales
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // patient + statut
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patientLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isRefunded ? 'Remboursé' : 'Payé',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // date de la séance
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        'Séance du ${formatDate(transaction.appointmentStartTime)}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // référence transaction
                  Text(
                    transaction.transactionReference,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // montants (colonne droite)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // montant net en avant
                Text(
                  (_isRefunded ? '- ' : '+ ') +
                      formatXof(transaction.netAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _isRefunded ? AppColors.gold : AppColors.tealDark,
                  ),
                ),
                const SizedBox(height: 2),
                // montant brut en petit
                Text(
                  'Brut ${formatXof(transaction.grossAmount)}',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11),
                ),
                Text(
                  'Commission ${formatXof(transaction.commissionAmount)}',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
