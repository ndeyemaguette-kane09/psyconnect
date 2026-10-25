import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';
import 'wallet_screen.dart';

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

  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  List<MapEntry<String, List<WalletTransaction>>> get _byMonth {
    final sorted = [..._transactions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final now = DateTime.now();
    final groups = <String, List<WalletTransaction>>{};
    for (final t in sorted) {
      final m = _months[t.createdAt.month - 1];
      final name = '${m[0].toUpperCase()}${m.substring(1)}';
      final key =
          t.createdAt.year == now.year ? name : '$name ${t.createdAt.year}';
      groups.putIfAbsent(key, () => []).add(t);
    }
    return groups.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
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
                'Historique du solde',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
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
                  'Aucun mouvement pour l\'instant. Vos recharges, retraits et '
                  'paiements de rendez-vous apparaîtront ici.',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
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
                        WalletTransactionRow(transaction: t),
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
