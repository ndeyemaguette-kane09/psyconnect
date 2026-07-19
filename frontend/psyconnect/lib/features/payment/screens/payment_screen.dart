import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../models/payment_models.dart';
import '../models/wallet_models.dart';
import '../services/payment_service.dart';
import '../services/wallet_service.dart';
import 'wallet_screen.dart';

// écran de paiement simulé : on paie avec le solde interne
// (rechargé sur WalletScreen). pas assez de solde -> le backend refuse et
// on propose de recharger. paiement ok confirme le RDV, sinon il reste
// en attente si on choisit "payer plus tard". pop(true) si ça a marché.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.appointmentId,
    required this.amount,
    required this.otherDisplayName,
    required this.patientId,
  });

  final int appointmentId;
  final int amount;
  final String otherDisplayName;
  final int patientId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _paymentService = PaymentService();
  final _walletService = WalletService();

  bool _loadingWallet = true;
  bool _paying = false;
  String? _error;
  Wallet? _wallet;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _loadingWallet = true);
    try {
      final wallet = await _walletService.getWallet(widget.patientId);
      if (!mounted) return;
      setState(() => _wallet = wallet);
    } catch (_) {
      // on dit rien, le backend verra de toute facon si le solde est trop bas
    } finally {
      if (mounted) setState(() => _loadingWallet = false);
    }
  }

  bool get _hasEnoughBalance =>
      _wallet == null || _wallet!.balance >= widget.amount;

  Future<void> _pay() async {
    // pour eviter le double clic : setState desactive le bouton qu'au prochain frame,
    // donc on verifie tout de suite ici en plus. le backend protege aussi de son cote.
    if (_paying) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      await _paymentService.createPayment(
        CreatePaymentRequest(
          appointmentId: widget.appointmentId,
          amount: widget.amount,
          method: PaymentMethod.wallet,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Paiement reçu'),
          content: Text(
            'Votre rendez-vous avec ${widget.otherDisplayName} est '
            'confirmé.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Le paiement a échoué.';
      });
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _skip() => Navigator.of(context).pop(false);

  Future<void> _goToWallet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WalletScreen(patientId: widget.patientId),
      ),
    );
    if (mounted) _loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(
                      'Consultation avec ${widget.otherDisplayName}',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${widget.amount} F CFA',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Moyen de paiement',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.teal, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.tealDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Solde PsyConnect',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            _loadingWallet
                                ? 'Chargement du solde…'
                                : 'Solde actuel : ${_wallet?.balance.toInt() ?? "—"} F CFA',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!_loadingWallet && !_hasEnoughBalance) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.gold, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Solde insuffisant pour ce rendez-vous.',
                              style: TextStyle(
                                  color: AppColors.text, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _goToWallet,
                        child: const Text('Recharger mon solde'),
                      ),
                    ],
                  ),
                ),
              ],
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
                      style: const TextStyle(color: AppColors.rose, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _paying ? null : _pay,
                child: _paying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Payer ${widget.amount} F CFA'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _paying ? null : _skip,
                  child: const Text('Payer plus tard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
