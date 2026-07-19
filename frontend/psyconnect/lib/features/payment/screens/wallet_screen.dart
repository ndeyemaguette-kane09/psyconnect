import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../models/payment_models.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';
import 'wallet_transactions_screen.dart';

// Écran "Mon solde PsyConnect" : dépôt, paiement de RDV et retrait.
// Les moyens de paiement sont simulés, mais le solde est bien persisté en base.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.patientId});

  final int patientId;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _walletService = WalletService();

  bool _loading = true;
  String? _error;
  Wallet? _wallet;

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
      final wallet = await _walletService.getWallet(widget.patientId);
      if (!mounted) return;
      setState(() => _wallet = wallet);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Solde indisponible.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDeposit() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WalletAmountSheet(
        title: 'Recharger mon solde',
        actionLabel: 'Recharger',
        onSubmit: (amount, method) async {
          await _walletService.deposit(
            widget.patientId,
            WalletAmountRequest(amount: amount, method: method),
          );
        },
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _openWithdraw() async {
    final balance = _wallet?.balance ?? 0;
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre solde PsyConnect est vide.')),
      );
      return;
    }
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WalletAmountSheet(
        title: 'Retirer mon solde',
        actionLabel: 'Retirer',
        maxAmount: balance,
        onSubmit: (amount, method) async {
          await _walletService.withdraw(
            widget.patientId,
            WalletAmountRequest(amount: amount, method: method),
          );
        },
      ),
    );
    if (result == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon solde PsyConnect'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Solde disponible',
                      style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _loading
                        ? const SizedBox(
                            height: 28,
                            width: 28,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            '${_formatAmount(_wallet?.balance ?? 0)} F CFA',
                            style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 30),
                          ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: AppColors.rose, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _openDeposit,
                      icon: const Icon(Icons.add),
                      label: const Text('Recharger'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _openWithdraw,
                      icon: const Icon(Icons.arrow_outward),
                      label: const Text('Retirer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        WalletTransactionsScreen(patientId: widget.patientId),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text("Voir l'historique des mouvements"),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.gold, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Solde simulé à des fins de démonstration : les '
                        'dépôts/retraits via Wave/Orange Money ne sont pas '
                        'réellement débités. Vos rendez-vous sont payés '
                        'depuis ce solde, et tout remboursement y est '
                        'crédité.',
                        style: TextStyle(color: AppColors.text, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatAmount(double amount) {
  return amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);
}

// Feuille partagée par "Recharger" et "Retirer" : saisie du montant et du moyen.
// maxAmount plafonne le retrait au solde disponible ; nul pour un dépôt.
class _WalletAmountSheet extends StatefulWidget {
  const _WalletAmountSheet({
    required this.title,
    required this.actionLabel,
    required this.onSubmit,
    this.maxAmount,
  });

  final String title;
  final String actionLabel;
  final double? maxAmount;
  final Future<void> Function(double amount, PaymentMethod method) onSubmit;

  @override
  State<_WalletAmountSheet> createState() => _WalletAmountSheetState();
}

class _WalletAmountSheetState extends State<_WalletAmountSheet> {
  final _amountController = TextEditingController();
  PaymentMethod _method = PaymentMethod.wave;
  bool _submitting = false;
  String? _error;

  static const _channels = [
    PaymentMethod.wave,
    PaymentMethod.orangeMoney,
    PaymentMethod.card,
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Saisissez un montant valide.');
      return;
    }
    if (widget.maxAmount != null && amount > widget.maxAmount!) {
      setState(() =>
          _error = 'Le montant dépasse votre solde disponible.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(amount, _method);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'L\'opération a échoué.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant (F CFA)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Via', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _channels
                  .map((m) => ChoiceChip(
                        label: Text(m.label),
                        selected: _method == m,
                        onSelected: _submitting
                            ? null
                            : (_) => setState(() => _method = m),
                      ))
                  .toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
