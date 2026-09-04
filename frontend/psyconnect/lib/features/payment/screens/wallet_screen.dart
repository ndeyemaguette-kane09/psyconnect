import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/payment_models.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';
import 'wallet_transactions_screen.dart';

const String _waveLogoAsset = 'assets/images/wave.png';
const String _orangeMoneyLogoAsset = 'assets/images/orange_money.png';

const Color _waveBlue = Color(0xFF1DC8F2);
const Color _orangeOrange = Color(0xFFFF7900);

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
      builder: (_) => _WalletAmountSheet(
        title: 'Recharger mon solde',
        subtitle: 'Choisissez un montant et un opérateur.',
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
      builder: (_) => _WalletAmountSheet(
        title: 'Retirer mon solde',
        subtitle: 'Vers le compte de votre choix.',
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
          color: AppColors.teal,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              // ── Solde ────────────────────────────────────────────────────
              AppHero(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SOLDE DISPONIBLE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: AppRadius.mdAll,
                          ),
                          child: const Text(
                            'Démonstration',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _loading
                        ? const SizedBox(
                            height: 34,
                            width: 34,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                formatAmount(_wallet?.balance ?? 0),
                                style: const TextStyle(
                                  color: AppColors.white,
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
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                AppCard(
                  color: AppColors.dangerBg,
                  shadow: const [],
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 19),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // ── Actions ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _openDeposit,
                      icon: const Icon(Icons.add, size: 19),
                      label: const Text('Recharger'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _openWithdraw,
                      icon: const Icon(Icons.arrow_outward, size: 18),
                      label: const Text('Retirer'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Opérateurs acceptés ──────────────────────────────────────
              const SectionHeader(
                title: 'Recharger avec',
                subtitle: 'Paiement mobile ou carte bancaire',
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(child: _OperatorTile(method: PaymentMethod.wave)),
                  SizedBox(width: 10),
                  Expanded(
                      child: _OperatorTile(method: PaymentMethod.orangeMoney)),
                  SizedBox(width: 10),
                  Expanded(child: _OperatorTile(method: PaymentMethod.card)),
                ],
              ),

              const SizedBox(height: 22),

              // ── Historique ───────────────────────────────────────────────
              AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        WalletTransactionsScreen(patientId: widget.patientId),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                          color: AppColors.tealDark, size: 20),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historique des mouvements',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Recharges, paiements et remboursements',
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.faint),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const AppNoticeCard(
                icon: Icons.info_outline,
                title: 'Solde de démonstration',
                message:
                    'Les recharges et retraits via Wave, Orange Money ou carte '
                    'ne sont pas réellement débités. Vos rendez-vous sont bien '
                    'payés depuis ce solde, et tout remboursement y est crédité.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marques des opérateurs
// ─────────────────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.method, this.size = 44});

  final PaymentMethod method;
  final double size;

  String? get _logoAsset {
    switch (method) {
      case PaymentMethod.wave:
        return _waveLogoAsset;
      case PaymentMethod.orangeMoney:
        return _orangeMoneyLogoAsset;
      case PaymentMethod.card:
      case PaymentMethod.wallet:
        return null;
    }
  }

  Color get _color {
    switch (method) {
      case PaymentMethod.wave:
        return _waveBlue;
      case PaymentMethod.orangeMoney:
        return _orangeOrange;
      case PaymentMethod.card:
        return AppColors.tealDark;
      case PaymentMethod.wallet:
        return AppColors.teal;
    }
  }

  String get _initials {
    switch (method) {
      case PaymentMethod.wave:
        return 'W';
      case PaymentMethod.orangeMoney:
        return 'OM';
      case PaymentMethod.card:
        return 'CB';
      case PaymentMethod.wallet:
        return 'PC';
    }
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * (_initials.length > 1 ? 0.32 : 0.42),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = _logoAsset;
    if (asset == null) return _fallback();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColors.border),
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      ),
    );
  }
}

class _OperatorTile extends StatelessWidget {
  const _OperatorTile({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandMark(method: method, size: 38),
          const SizedBox(height: 9),
          Text(
            method.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feuille de recharge / retrait
// ─────────────────────────────────────────────────────────────────────────────

class _WalletAmountSheet extends StatefulWidget {
  const _WalletAmountSheet({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onSubmit,
    this.maxAmount,
  });

  final String title;
  final String subtitle;
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

  static const _presets = [2000, 5000, 10000, 25000];

  bool get _isDeposit => widget.maxAmount == null;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _amount =>
      double.tryParse(_amountController.text.replaceAll(',', '.'));

  Future<void> _submit() async {
    final amount = _amount;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Saisissez un montant valide.');
      return;
    }
    if (widget.maxAmount != null && amount > widget.maxAmount!) {
      setState(() => _error = 'Le montant dépasse votre solde disponible.');
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
    final amount = _amount;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: theme.textTheme.bodySmall),

              const SizedBox(height: 20),

              // ── Montant ────────────────────────────────────────────────
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  hintText: '0',
                  suffixText: 'F CFA',
                ),
              ),

              if (_isDeposit) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final preset in _presets) ...[
                      Expanded(
                        child: _PresetChip(
                          amount: preset,
                          selected: amount != null && amount == preset,
                          onTap: _submitting
                              ? null
                              : () => setState(() =>
                                  _amountController.text = preset.toString()),
                        ),
                      ),
                      if (preset != _presets.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Disponible : ${formatAmount(widget.maxAmount ?? 0)} F CFA',
                  style: theme.textTheme.bodySmall,
                ),
              ],

              const SizedBox(height: 22),

              // ── Opérateur ──────────────────────────────────────────────
              Text(
                _isDeposit ? 'Payer avec' : 'Recevoir sur',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              for (final channel in _channels) ...[
                _MethodOption(
                  method: channel,
                  selected: _method == channel,
                  onTap: _submitting
                      ? null
                      : () => setState(() => _method = channel),
                ),
                if (channel != _channels.last) const SizedBox(height: 10),
              ],

              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Opérateur simulé : aucun montant n\'est réellement '
                      'débité ni versé.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                AppCard(
                  color: AppColors.dangerBg,
                  shadow: const [],
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(
                        amount != null && amount > 0
                            ? '${widget.actionLabel} ${formatAmount(amount)} F CFA'
                            : widget.actionLabel,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final int amount;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal : AppColors.white,
      borderRadius: AppRadius.smAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
            ),
          ),
          child: Text(
            formatAmount(amount),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback? onTap;

  String get _subtitle {
    switch (method) {
      case PaymentMethod.wave:
        return 'Paiement mobile · sans frais';
      case PaymentMethod.orangeMoney:
        return 'Paiement mobile · sans frais';
      case PaymentMethod.card:
        return 'Visa · Mastercard';
      case PaymentMethod.wallet:
        return 'Solde interne';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: selected ? AppColors.teal : AppColors.border,
      shadow: selected ? null : const [],
      child: Row(
        children: [
          _BrandMark(method: method, size: 42),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.teal : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.teal : AppColors.borderStrong,
                width: 1.6,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
        ],
      ),
    );
  }
}
