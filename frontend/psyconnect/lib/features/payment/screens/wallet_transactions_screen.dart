import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';

// Relevé des mouvements du solde (dépôts, retraits, paiements de
// rendez-vous, remboursements), pour compléter [WalletScreen].
class WalletTransactionsScreen extends StatefulWidget {
  const WalletTransactionsScreen({super.key, required this.patientId});

  final int patientId;

  @override
  State<WalletTransactionsScreen> createState() =>
      _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  final _walletService = WalletService();

  bool _loading = true;
  String? _error;
  List<WalletTransaction> _transactions = [];

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
      final transactions = await _walletService.getTransactions(widget.patientId);
      if (!mounted) return;
      setState(() => _transactions = transactions);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Historique indisponible.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Historique du solde'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
            ),
            child: Text(_error!,
                style: const TextStyle(color: AppColors.rose, fontSize: 13)),
          ),
        ],
      );
    }

    if (_transactions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 32),
        children: const [
          Center(
            child: Text(
              "Aucun mouvement pour l'instant.\nVos recharges, retraits et "
              'paiements de rendez-vous apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _TransactionTile(
        transaction: _transactions[index],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type.isCredit;
    final color = isCredit ? AppColors.teal : AppColors.rose;
    final sign = isCredit ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.tealMid.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              isCredit ? Icons.south_west : Icons.north_east,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.type.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(transaction.createdAt) +
                      (transaction.method != null
                          ? ' • ${transaction.method}'
                          : ''),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${_formatAmount(transaction.amount)} F CFA',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Solde : ${_formatAmount(transaction.balanceAfter)} F CFA',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatAmount(double amount) {
  return amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year} à '
      '${date.hour.toString().padLeft(2, '0')}h'
      '${date.minute.toString().padLeft(2, '0')}';
}
