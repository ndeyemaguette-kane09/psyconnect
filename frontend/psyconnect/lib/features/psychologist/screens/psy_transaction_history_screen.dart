import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/services/profile_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/services/payment_service.dart';
import '../utils/patient_name.dart';

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
  // patientId -> label affiché (pseudo ou "Patient #X" si anonyme ou si erreur)
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
            labelMap[pid] = patientDisplayName(profile);
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
    return buf.toString();
  }

  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  static const _monthsShort = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day} ${_monthsShort[dt.month - 1]}';
  }

  List<MapEntry<String, List<PaymentTransaction>>> get _byMonth {
    final sorted = [..._transactions]
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    final now = DateTime.now();
    final groups = <String, List<PaymentTransaction>>{};
    for (final t in sorted) {
      final m = _months[t.paidAt.month - 1];
      final key = t.paidAt.year == now.year
          ? '${m[0].toUpperCase()}${m.substring(1)}'
          : '${m[0].toUpperCase()}${m.substring(1)} ${t.paidAt.year}';
      groups.putIfAbsent(key, () => []).add(t);
    }
    return groups.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalNet = _transactions
        .where((t) => t.status != PaymentStatus.refunded)
        .fold<double>(0, (sum, t) => sum + t.netAmount);

    return Scaffold(
      appBar: AppBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Paiements reçus',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
              ),
            ),
            if (!_loading && _transactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  '${_transactions.length} paiement'
                  '${_transactions.length > 1 ? 's' : ''} · '
                  '${_formatXof(totalNet)} F nets',
                  style:
                      const TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else if (_transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Les paiements de vos patients apparaîtront ici.',
                  style: TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              )
            else
              for (final group in _byMonth) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    group.key,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      for (final t in group.value)
                        _TransactionRow(
                          transaction: t,
                          patientLabel: t.patientId != null
                              ? (_patientLabels[t.patientId!] ??
                                  'Patient #${t.patientId}')
                              : 'Patient',
                          formatXof: _formatXof,
                          formatDate: _formatDate,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
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
    final rate = transaction.grossAmount > 0
        ? (transaction.commissionAmount / transaction.grossAmount * 100)
            .round()
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          AppAvatar(name: patientLabel, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  'Séance du ${formatDate(transaction.appointmentStartTime)} · '
                  '${formatXof(transaction.grossAmount)} F moins $rate %',
                  style:
                      const TextStyle(fontSize: 13.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_isRefunded ? '−' : '+'} ${formatXof(transaction.netAmount)} F',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _isRefunded ? AppColors.muted : AppColors.teal,
                ),
              ),
              if (_isRefunded)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Remboursé',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
