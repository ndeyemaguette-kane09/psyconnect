import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/services/appointment_service.dart';
import '../../patient/services/psychologist_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/screens/psy_wallet_screen.dart';
import '../../payment/services/payment_service.dart';
import 'psy_transaction_history_screen.dart';
import 'psychologist_profile_screen.dart';

class PsychologistStatsTab extends StatefulWidget {
  const PsychologistStatsTab({super.key});

  @override
  State<PsychologistStatsTab> createState() => _PsychologistStatsTabState();
}

class _PsychologistStatsTabState extends State<PsychologistStatsTab> {
  final _appointmentService = AppointmentService();
  final _psychologistService = PsychologistService();
  final _paymentService = PaymentService();

  bool _loading = true;
  String? _error;
  PsychologistProfile? _me;
  List<Appointment> _appointments = [];
  PsychologistRevenue? _revenue;
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

    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) {
      setState(() {
        _error = 'Profil psychologue introuvable.';
        _loading = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        _psychologistService.getPsychologistById(psychologistId),
        _appointmentService.getAppointmentsByPsychologistId(psychologistId),
      ]);
      if (!mounted) return;
      setState(() {
        _me = results[0] as PsychologistProfile;
        _appointments = results[1] as List<Appointment>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les statistiques.';
        _loading = false;
      });
      return;
    }

    try {
      final revenue = await _paymentService.getPsychologistRevenue(psychologistId);
      if (!mounted) return;
      setState(() => _revenue = revenue);
    } catch (_) {}

    try {
      final wallet = await _paymentService.getPsychologistWallet(psychologistId);
      if (!mounted) return;
      setState(() => _wallet = wallet);
    } catch (_) {}
  }

  Future<void> _openWallet() async {
    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PsyWalletScreen(psychologistId: psychologistId),
      ),
    );
    if (mounted) _load();
  }

  int _countByStatus(AppointmentStatus status) =>
      _appointments.where((a) => a.status == status).length;

  String _formatXof(double amount) {
    final rounded = amount.round();
    final digits = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
            'Vous devrez vous reconnecter pour accéder à votre compte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  void _openTransactions() {
    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PsyTransactionHistoryScreen(psychologistId: psychologistId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final fullName = me == null ? 'Profil' : '${me.firstName} ${me.lastName}';
    final patients = _appointments.map((a) => a.patientId).toSet().length;
    final buckets = [
      _Bucket('À confirmer', _countByStatus(AppointmentStatus.pending),
          AppColors.gold),
      _Bucket('Confirmées', _countByStatus(AppointmentStatus.confirmed),
          AppColors.teal),
      _Bucket('Terminées', _countByStatus(AppointmentStatus.completed),
          AppColors.faint),
      _Bucket(
          'Annulées ou refusées',
          _countByStatus(AppointmentStatus.cancelled) +
              _countByStatus(AppointmentStatus.rejected),
          AppColors.rose),
    ];
    final month = _kMonthNames[DateTime.now().month - 1];
    final hasReviews = me != null && (me.totalReviews ?? 0) > 0;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          children: [
            Text(
              'Mon activité',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PsychologistProfileScreen(),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                        child: Row(
                          children: [
                            AppAvatar(name: fullName, size: 40),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mon profil',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Text(
                                    'Voir et modifier',
                                    style: TextStyle(
                                        fontSize: 13, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.muted, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _logout,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(
                        children: [
                          Icon(Icons.logout_rounded,
                              color: AppColors.danger, size: 22),
                          SizedBox(height: 2),
                          Text(
                            'Déconnexion',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else ...[
              if (_revenue != null) ...[
                Text(
                  'Revenu net en $month',
                  style: const TextStyle(fontSize: 16, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                          text: _formatXof(_revenue!.currentMonthNetRevenue)),
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
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                    height: 1.05,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatXof(_revenue!.totalNetRevenue)} F depuis le début · '
                  'après commission de '
                  '${_revenue!.commissionRatePercent.toStringAsFixed(0)} %',
                  style: const TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _openTransactions,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text(
                      'Voir le détail des paiements',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Material(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _wallet == null ? _load : _openWallet,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Disponible à retirer',
                                style: TextStyle(
                                    fontSize: 15, color: AppColors.muted),
                              ),
                              Text(
                                _wallet == null
                                    ? 'Indisponible, touchez pour réessayer'
                                    : '${_formatXof(_wallet!.availableBalance)} F',
                                style: TextStyle(
                                  fontSize: _wallet == null ? 15 : 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_wallet != null)
                          FilledButton(
                            onPressed: _openWallet,
                            child: Text(_wallet!.availableBalance > 0
                                ? 'Retirer'
                                : 'Ouvrir'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Mes consultations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              if (_appointments.isEmpty)
                const Text(
                  'Aucune consultation pour l\'instant.',
                  style: TextStyle(fontSize: 15.5, color: AppColors.muted),
                )
              else ...[
                SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      for (final b in buckets.where((b) => b.count > 0)) ...[
                        Expanded(
                          flex: b.count,
                          child: Container(
                            decoration: BoxDecoration(
                              color: b.color,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final b in buckets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: b.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            b.label,
                            style: const TextStyle(
                                fontSize: 16, color: AppColors.text),
                          ),
                        ),
                        Text(
                          '${b.count}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              const Text(
                'Mes patients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: '$patients patient${patients > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const TextSpan(text: ' au total. '),
                    TextSpan(
                      text: hasReviews
                          ? 'Note moyenne de '
                              '${(me.rating ?? 0).toStringAsFixed(1).replaceAll('.', ',')}'
                              ' sur ${me.totalReviews ?? 0} avis.'
                          : 'Pas encore d\'avis : ils arrivent après une '
                              'consultation terminée.',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _kMonthNames = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

class _Bucket {
  const _Bucket(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}
