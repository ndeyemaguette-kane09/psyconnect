import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../psychologist/screens/psy_transaction_history_screen.dart';
import '../models/payment_models.dart';
import '../services/payment_service.dart';

const String _waveLogoAsset = 'assets/images/wave.png';
const String _orangeMoneyLogoAsset = 'assets/images/orange_money.png';

const Color _waveBlue = Color(0xFF1DC8F2);
const Color _orangeOrange = Color(0xFFFF7900);

class PsyWalletScreen extends StatefulWidget {
  const PsyWalletScreen({super.key, required this.psychologistId});

  final int psychologistId;

  @override
  State<PsyWalletScreen> createState() => _PsyWalletScreenState();
}

class _PsyWalletScreenState extends State<PsyWalletScreen> {
  final _paymentService = PaymentService();

  bool _loading = true;
  String? _error;
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
    try {
      final wallet =
          await _paymentService.getPsychologistWallet(widget.psychologistId);
      if (!mounted) return;
      setState(() => _wallet = wallet);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Portefeuille indisponible.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWithdraw() async {
    final balance = _wallet?.availableBalance ?? 0;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WithdrawSheet(
        maxAmount: balance,
        onSubmit: (amount, method) async {
          await _paymentService.withdraw(
            psychologistId: widget.psychologistId,
            amount: amount,
            method: method,
          );
        },
      ),
    );
    if (result == true) await _load();
  }

  final _withdrawalsKey = GlobalKey();

  void _openPayments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PsyTransactionHistoryScreen(
          psychologistId: widget.psychologistId,
        ),
      ),
    );
  }

  void _showWithdrawals() {
    final ctx = _withdrawalsKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    final balance = wallet?.availableBalance ?? 0;
    final canWithdraw = !_loading && wallet != null && balance > 0;

    return Scaffold(
      appBar: AppBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
          children: [
            const Text(
              'Disponible à retirer',
              style: TextStyle(fontSize: 16, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              )
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: formatAmount(balance)),
                    const TextSpan(
                      text: ' F CFA',
                      style: TextStyle(
                        fontSize: 22,
                        color: AppColors.muted,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1,
                  color: AppColors.text,
                ),
              ),
            const SizedBox(height: 8),
            if (wallet != null)
              Text(
                'Après la commission PsyConnect de '
                '${wallet.commissionRatePercent.toStringAsFixed(0)} %',
                style: const TextStyle(fontSize: 14.5, color: AppColors.muted),
              ),
            const Text(
              'Mode démonstration : aucun virement réel',
              style: TextStyle(fontSize: 14, color: AppColors.goldDark),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.dangerBg,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 14.5),
                      ),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: _WalletAction(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Retirer',
                    primary: true,
                    onTap: canWithdraw ? _openWithdraw : null,
                  ),
                ),
                Expanded(
                  child: _WalletAction(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Paiements reçus',
                    onTap: _openPayments,
                  ),
                ),
                Expanded(
                  child: _WalletAction(
                    icon: Icons.history_rounded,
                    label: 'Mes retraits',
                    onTap: _showWithdrawals,
                  ),
                ),
              ],
            ),
            if (!_loading && _error == null && balance <= 0) ...[
              const SizedBox(height: 14),
              const Text(
                'Rien à retirer pour l\'instant. Votre solde se remplit à '
                'chaque consultation payée par un patient.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            ],
            if (wallet != null) ...[
              const SizedBox(height: 30),
              const Text(
                'En résumé',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Revenus nets encaissés',
                value: wallet.totalNetRevenue,
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Déjà retiré',
                value: wallet.totalWithdrawn,
              ),
            ],
            const SizedBox(height: 30),
            Text(
              'Mes retraits',
              key: _withdrawalsKey,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            if (wallet == null || wallet.withdrawals.isEmpty)
              const Text(
                'Aucun retrait pour l\'instant.',
                style: TextStyle(fontSize: 15.5, color: AppColors.muted),
              )
            else
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final w in wallet.withdrawals)
                      _WithdrawalRow(withdrawal: w),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = primary
        ? (enabled ? AppColors.teal : AppColors.borderStrong)
        : AppColors.white;
    final ink = primary ? AppColors.background : AppColors.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: ink, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: primary ? FontWeight.w800 : FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 16),
          ),
        ),
        Text(
          '${formatAmount(value)} F',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _WithdrawalRow extends StatelessWidget {
  const _WithdrawalRow({required this.withdrawal});

  final PsychologistWithdrawal withdrawal;

  static const _monthNames = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  WithdrawalMethod? get _method {
    switch (withdrawal.method.toUpperCase()) {
      case 'WAVE':
        return WithdrawalMethod.wave;
      case 'ORANGE_MONEY':
        return WithdrawalMethod.orangeMoney;
      case 'BANK_TRANSFER':
        return WithdrawalMethod.bankTransfer;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = _method;
    final d = withdrawal.createdAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          if (method != null)
            _PayoutMark(method: method, size: 44)
          else
            const SizedBox(width: 44, height: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method == null
                      ? 'Retrait · ${withdrawal.method}'
                      : 'Retrait · ${method.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${d.day} ${_monthNames[d.month - 1]} ${d.year}',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            '− ${formatAmount(withdrawal.amount)} F',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// Marques des opérateurs

class _PayoutMark extends StatelessWidget {
  const _PayoutMark({required this.method, this.size = 44});

  final WithdrawalMethod method;
  final double size;

  String? get _logoAsset {
    switch (method) {
      case WithdrawalMethod.wave:
        return _waveLogoAsset;
      case WithdrawalMethod.orangeMoney:
        return _orangeMoneyLogoAsset;
      case WithdrawalMethod.bankTransfer:
        return null;
    }
  }

  Color get _color {
    switch (method) {
      case WithdrawalMethod.wave:
        return _waveBlue;
      case WithdrawalMethod.orangeMoney:
        return _orangeOrange;
      case WithdrawalMethod.bankTransfer:
        return AppColors.tealDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _logoAsset;

    if (asset == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _color,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(
          Icons.account_balance_outlined,
          color: Colors.white,
          size: size * 0.5,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: _color,
          child: Text(
            method == WithdrawalMethod.wave ? 'W' : 'OM',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * (method == WithdrawalMethod.wave ? 0.42 : 0.32),
            ),
          ),
        ),
      ),
    );
  }
}

// Feuille de retrait

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.maxAmount, required this.onSubmit});

  final double maxAmount;
  final Future<void> Function(double amount, WithdrawalMethod method) onSubmit;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountController = TextEditingController();
  WithdrawalMethod _method = WithdrawalMethod.wave;
  bool _submitting = false;
  String? _error;

  static const _channels = [
    WithdrawalMethod.wave,
    WithdrawalMethod.orangeMoney,
    WithdrawalMethod.bankTransfer,
  ];

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
    if (amount > widget.maxAmount) {
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
        _error = e is ApiException ? e.message : 'Le retrait a échoué.';
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
              Text('Retirer mes fonds', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Vers le compte de votre choix.',
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: 20),

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

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Disponible : ${formatAmount(widget.maxAmount)} F CFA',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _amountController.text =
                            widget.maxAmount.toStringAsFixed(0)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Tout retirer'),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Text('Recevoir sur', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              for (final channel in _channels) ...[
                _PayoutOption(
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
                  Expanded(
                    child: Text(
                      'Opérateur simulé : aucun virement n\'est réellement '
                      'effectué.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                AppCard(
                  color: AppColors.dangerBg,
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
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(
                        amount != null && amount > 0
                            ? 'Retirer ${formatAmount(amount)} F CFA'
                            : 'Retirer',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutOption extends StatelessWidget {
  const _PayoutOption({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final WithdrawalMethod method;
  final bool selected;
  final VoidCallback? onTap;

  String get _subtitle {
    switch (method) {
      case WithdrawalMethod.wave:
        return 'Transfert mobile · sous 24 h';
      case WithdrawalMethod.orangeMoney:
        return 'Transfert mobile · sous 24 h';
      case WithdrawalMethod.bankTransfer:
        return 'Compte bancaire · sous 72 h';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: selected ? AppColors.tealSoft : AppColors.white,
      borderColor: selected ? AppColors.teal : null,
      child: Row(
        children: [
          _PayoutMark(method: method, size: 42),
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
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12),
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
