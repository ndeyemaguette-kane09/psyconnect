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

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    final balance = wallet?.availableBalance ?? 0;
    final canWithdraw = !_loading && wallet != null && balance > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon portefeuille'),
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
                                formatAmount(balance),
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
                    if (wallet != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Après commission de '
                        '${wallet.commissionRatePercent.toStringAsFixed(0)} % '
                        'prélevée par la plateforme.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _load,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              ElevatedButton.icon(
                onPressed: canWithdraw ? _openWithdraw : null,
                icon: const Icon(Icons.arrow_outward, size: 19),
                label: const Text('Retirer mes fonds'),
              ),

              if (!_loading && _error == null && balance <= 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Aucun montant à retirer pour l\'instant. Votre solde se '
                  'remplit à chaque consultation payée par un patient.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],

              if (wallet != null) ...[
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Revenus nets encaissés',
                        value: wallet.totalNetRevenue,
                      ),
                      const Divider(height: 22),
                      _SummaryRow(
                        label: 'Déjà retiré',
                        value: wallet.totalWithdrawn,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              const SectionHeader(
                title: 'Recevoir sur',
                subtitle: 'Transfert mobile ou virement bancaire',
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(child: _PayoutTile(method: WithdrawalMethod.wave)),
                  SizedBox(width: 10),
                  Expanded(
                      child:
                          _PayoutTile(method: WithdrawalMethod.orangeMoney)),
                  SizedBox(width: 10),
                  Expanded(
                      child:
                          _PayoutTile(method: WithdrawalMethod.bankTransfer)),
                ],
              ),

              const SizedBox(height: 24),

              const SectionHeader(title: 'Mes retraits'),
              const SizedBox(height: 12),
              if (wallet == null || wallet.withdrawals.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: const Text(
                    'Aucun retrait effectué',
                    style: TextStyle(color: AppColors.muted, fontSize: 13.5),
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < wallet.withdrawals.length; i++) ...[
                        _WithdrawalRow(withdrawal: wallet.withdrawals[i]),
                        if (i != wallet.withdrawals.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PsyTransactionHistoryScreen(
                      psychologistId: widget.psychologistId,
                    ),
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
                            'Paiements reçus',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Le détail séance par séance',
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
                title: 'Versements de démonstration',
                message:
                    'Les retraits vers Wave, Orange Money ou un compte bancaire '
                    'ne donnent lieu à aucun virement réel. Ils sont enregistrés '
                    'et déduits de votre solde comme le ferait un versement.',
              ),
            ],
          ),
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
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        Text(
          '${formatAmount(value)} F CFA',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
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
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  String get _methodLabel {
    switch (withdrawal.method.toUpperCase()) {
      case 'WAVE':
        return 'Wave';
      case 'ORANGE_MONEY':
        return 'Orange Money';
      case 'BANK_TRANSFER':
        return 'Virement bancaire';
      default:
        return withdrawal.method;
    }
  }

  String get _date {
    final d = withdrawal.createdAt;
    return '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _methodLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _date,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '− ${formatAmount(withdrawal.amount)} F CFA',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.tealDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marques des opérateurs
// ─────────────────────────────────────────────────────────────────────────────

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
        border: Border.all(color: AppColors.border),
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

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.method});

  final WithdrawalMethod method;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PayoutMark(method: method, size: 38),
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
// Feuille de retrait
// ─────────────────────────────────────────────────────────────────────────────

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
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 7),
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
      borderColor: selected ? AppColors.teal : AppColors.border,
      shadow: selected ? null : const [],
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
