import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/payment_models.dart';
import '../models/wallet_models.dart';
import '../services/payment_service.dart';
import '../services/wallet_service.dart';
import 'wallet_screen.dart';

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
      // Silencieux : le backend refusera de toute façon si le solde est trop bas.
    } finally {
      if (mounted) setState(() => _loadingWallet = false);
    }
  }

  bool get _hasEnoughBalance =>
      _wallet == null || _wallet!.balance >= widget.amount;

  int get _missingAmount {
    final balance = _wallet?.balance ?? 0;
    final missing = widget.amount - balance;
    return missing > 0 ? missing.ceil() : 0;
  }

  Future<void> _pay() async {
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
        builder: (_) => _PaymentSuccessDialog(
          amount: widget.amount,
          otherDisplayName: widget.otherDisplayName,
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
    final canPay = !_paying && !_loadingWallet && _hasEnoughBalance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  // ── Montant à régler ───────────────────────────────────
                  AppHero(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONTANT À RÉGLER',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatAmount(widget.amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 34,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'F CFA',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(height: 1, color: Colors.white24),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                color: Colors.white70, size: 17),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.otherDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.schedule,
                                color: Colors.white70, size: 17),
                            const SizedBox(width: 8),
                            Text(
                              'Séance de consultation',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── Moyen de paiement ──────────────────────────────────
                  const SectionHeader(
                    title: 'Moyen de paiement',
                    subtitle: 'Les rendez-vous sont réglés depuis votre solde',
                  ),
                  const SizedBox(height: 12),
                  _WalletMethodTile(
                    loading: _loadingWallet,
                    balance: _wallet?.balance,
                    enough: _hasEnoughBalance,
                  ),

                  if (!_loadingWallet && !_hasEnoughBalance) ...[
                    const SizedBox(height: 12),
                    _TopUpNotice(
                      missing: _missingAmount,
                      onTopUp: _paying ? null : _goToWallet,
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorNotice(message: _error!),
                  ],

                  const SizedBox(height: 22),

                  // ── Récapitulatif ──────────────────────────────────────
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Consultation',
                          value: '${formatAmount(widget.amount)} F',
                        ),
                        const Divider(height: 1),
                        const _SummaryRow(
                          label: 'Frais de service',
                          value: 'Offerts',
                          valueColor: AppColors.success,
                        ),
                        const Divider(height: 1),
                        _SummaryRow(
                          label: 'Total',
                          value: '${formatAmount(widget.amount)} F CFA',
                          strong: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 15, color: AppColors.muted),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Le montant est débité de votre solde PsyConnect. '
                          'En cas d\'annulation au moins 48 h avant la séance, '
                          'il vous est intégralement recrédité.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Barre d'action fixe ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: canPay ? _pay : null,
                    child: _paying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : Text(
                            _hasEnoughBalance
                                ? 'Payer ${formatAmount(widget.amount)} F CFA'
                                : 'Solde insuffisant',
                          ),
                  ),
                  TextButton(
                    onPressed: _paying ? null : _skip,
                    child: const Text('Payer plus tard'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WalletMethodTile extends StatelessWidget {
  const _WalletMethodTile({
    required this.loading,
    required this.balance,
    required this.enough,
  });

  final bool loading;
  final double? balance;
  final bool enough;

  @override
  Widget build(BuildContext context) {
    final accent = enough ? AppColors.teal : AppColors.warning;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: accent,
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
                color: accent, size: 21),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solde PsyConnect',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  loading
                      ? 'Chargement du solde…'
                      : balance == null
                          ? 'Solde indisponible'
                          : 'Disponible : ${formatAmount(balance!.round())} F CFA',
                  style: TextStyle(
                    color: enough ? AppColors.muted : AppColors.warning,
                    fontSize: 12.5,
                    fontWeight: enough ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!loading)
            Icon(
              enough ? Icons.check_circle : Icons.error_outline,
              color: accent,
              size: 22,
            ),
        ],
      ),
    );
  }
}

class _TopUpNotice extends StatelessWidget {
  const _TopUpNotice({required this.missing, required this.onTopUp});

  final int missing;
  final VoidCallback? onTopUp;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.warningBg,
      shadow: const [],
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.warning, size: 19),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Il vous manque ${formatAmount(missing)} F CFA pour régler '
                  'cette séance. Rechargez votre solde avec Wave, Orange Money '
                  'ou une carte bancaire.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTopUp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 46),
                backgroundColor: AppColors.warning,
              ),
              child: const Text('Recharger mon solde'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.dangerBg,
      shadow: const [],
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: strong ? AppColors.text : AppColors.muted,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 15.5 : 13.5,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSuccessDialog extends StatelessWidget {
  const _PaymentSuccessDialog({
    required this.amount,
    required this.otherDisplayName,
  });

  final int amount;
  final String otherDisplayName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 32),
            const SizedBox(height: 18),
            Text(
              'Paiement reçu',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${formatAmount(amount)} F CFA ont été débités de votre solde. '
              'Votre rendez-vous avec $otherDisplayName est confirmé.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Terminé'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
