import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../companion/screens/xalaat_screen.dart';
import '../../journal/screens/journal_screen.dart';
import '../../payment/models/wallet_models.dart';
import '../../payment/screens/wallet_screen.dart';
import '../../payment/services/wallet_service.dart';
import '../../psychologist/models/recommendation_models.dart';
import '../../psychologist/services/recommendation_service.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../services/appointment_service.dart';
import '../services/notification_service.dart';
import '../services/psychologist_service.dart';
import '../widgets/psychologist_card.dart';
import 'announcements_screen.dart';
import 'emergency_screen.dart';
import 'notifications_screen.dart';
import 'psychologist_profile_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({
    super.key,
    required this.onOpenSearch,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenSearch;

  final VoidCallback onOpenProfile;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _psychologistService = PsychologistService();
  final _appointmentService = AppointmentService();
  final _profileService = ProfileService();
  final _walletService = WalletService();
  final _notificationService = NotificationService();
  final _recommendationService = RecommendationService();
  final _api = ApiClient();
  final _storage = const FlutterSecureStorage();

  bool _loading = true;
  List<PsychologistProfile> _recommended = [];
  Appointment? _nextAppointment;
  PsychologistProfile? _nextAppointmentPsychologist;
  PatientProfile? _patientProfile;
  Wallet? _wallet;
  int _unreadNotifCount = 0;
  int _newBroadcastCount = 0;
  List<SessionRecommendation> _pendingRecommendations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final patientId = context.read<AuthProvider>().session?.profileId;

    List<PsychologistProfile> psychologists = [];
    try {
      psychologists = await _psychologistService.getAllPsychologists();
    } catch (_) {}

    List<PsychologistProfile> recommended = [];
    if (patientId != null) {
      try {
        recommended = await _psychologistService.getRecommendations(
          patientId,
          topN: 5,
        );
      } catch (_) {}
    }
    if (recommended.isEmpty) {
      recommended = ([...psychologists]
            ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0)))
          .take(5)
          .toList();
    }

    PatientProfile? patientProfile;
    if (patientId != null) {
      try {
        patientProfile = await _profileService.getPatientProfileById(patientId);
      } catch (_) {}
    }

    Wallet? wallet;
    if (patientId != null) {
      try {
        wallet = await _walletService.getWallet(patientId);
      } catch (_) {}
    }

    Appointment? next;
    PsychologistProfile? nextPsy;
    if (patientId != null) {
      try {
        final appointments =
            await _appointmentService.getAppointmentsByPatientId(patientId);
        final now = DateTime.now();
        final upcoming = appointments.where((a) =>
            a.startTime.isAfter(now) &&
            (a.status == AppointmentStatus.pending ||
                a.status == AppointmentStatus.confirmed)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        if (upcoming.isNotEmpty) {
          next = upcoming.first;
          nextPsy = psychologists
              .where((p) => p.id == next!.psychologistId)
              .cast<PsychologistProfile?>()
              .firstWhere((_) => true, orElse: () => null);
        }
      } catch (_) {}
    }

    List<SessionRecommendation> pendingRecos = [];
    try {
      pendingRecos = await _recommendationService.getMyPendingRecommendations();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _recommended = recommended;
      _nextAppointment = next;
      _nextAppointmentPsychologist = nextPsy;
      _patientProfile = patientProfile;
      _wallet = wallet;
      _pendingRecommendations = pendingRecos;
      _loading = false;
    });

    _refreshUnreadNotifCount();
    _refreshBroadcastBadge();
  }

  Future<void> _refreshUnreadNotifCount() async {
    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) return;
    try {
      final notifs =
          await _notificationService.getNotificationsByUserId(patientId);
      final unread = notifs.where((n) => !n.isRead).length;
      if (mounted) setState(() => _unreadNotifCount = unread);
    } catch (_) {}
  }

  Future<void> _openNotifications(int patientId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(userId: patientId),
      ),
    );
    if (mounted) _refreshUnreadNotifCount();
  }

  Future<void> _refreshBroadcastBadge() async {
    try {
      final json = await _api.get(ApiConstants.broadcasts);
      final broadcasts = (json as List).cast<Map<String, dynamic>>();

      final lastSeenStr =
          await _storage.read(key: 'patient_broadcasts_last_seen');
      final lastSeen = lastSeenStr != null
          ? DateTime.tryParse(lastSeenStr) ??
              DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0);

      final newCount = broadcasts.where((b) {
        final raw = b['sentAt'] as String?;
        if (raw == null) return false;
        final sentAt = DateTime.tryParse(raw);
        return sentAt != null && sentAt.isAfter(lastSeen);
      }).length;

      if (mounted) setState(() => _newBroadcastCount = newCount);
    } catch (_) {}
  }

  Future<void> _openAnnouncements() async {
    final lastSeenStr =
        await _storage.read(key: 'patient_broadcasts_last_seen');
    final lastSeen =
        lastSeenStr == null ? null : DateTime.tryParse(lastSeenStr);

    if (!mounted) return;
    setState(() => _newBroadcastCount = 0);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnnouncementsScreen(lastSeen: lastSeen),
      ),
    );

    await _storage.write(
      key: 'patient_broadcasts_last_seen',
      value: DateTime.now().toIso8601String(),
    );
    if (mounted) _refreshBroadcastBadge();
  }

  Future<void> _openWallet(int patientId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WalletScreen(patientId: patientId)),
    );
    if (mounted) _load();
  }

  List<String> get _missingProfileFields {
    final profile = _patientProfile;
    if (profile == null) return [];
    final missing = <String>[];
    if (profile.preferredLanguage == null ||
        profile.preferredLanguage!.trim().isEmpty) {
      missing.add('langue préférée');
    }
    if (profile.emergencyContactName == null ||
        profile.emergencyContactName!.trim().isEmpty) {
      missing.add("contact d'urgence");
    }
    return missing;
  }

  void _onIncompleteProfileTap() => widget.onOpenProfile();

  Future<void> _markRecommendationDone(SessionRecommendation reco) async {
    try {
      await _recommendationService.markCompleted(reco.id);
      if (!mounted) return;
      setState(
          () => _pendingRecommendations.removeWhere((r) => r.id == reco.id));
    } catch (_) {}
  }

  void _openProfile(int psychologistId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PsychologistProfileScreen(psychologistId: psychologistId),
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;

    final displayName =
        (_patientProfile?.firstName.trim().isNotEmpty ?? false)
            ? _patientProfile!.firstName.trim()
            : (session?.pseudo ?? '');

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.teal,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HomeHero(
            greeting: _greeting,
            name: displayName,
            broadcastCount: _newBroadcastCount,
            notifCount: _unreadNotifCount,
            onOpenAnnouncements: _openAnnouncements,
            onOpenNotifications: session?.profileId == null
                ? null
                : () => _openNotifications(session!.profileId!),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SosButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                  ),
                ),
                const SizedBox(height: 22),
                if (!_loading && _missingProfileFields.isNotEmpty)
                  _ProfileReminder(
                    missing: _missingProfileFields,
                    onTap: _onIncompleteProfileTap,
                  ),
                AppListRow(
                  icon: Icons.book_outlined,
                  title: 'Mon journal',
                  subtitle: 'Noter mon humeur du jour',
                  showTopBorder: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JournalScreen()),
                  ),
                ),
                AppListRow(
                  icon: Icons.spa_outlined,
                  title: 'Parler à Xalaat',
                  subtitle: 'Confidentiel et éphémère',
                  iconColor: AppColors.goldDark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const XalaatScreen()),
                  ),
                ),
                if (!_loading && session?.profileId != null)
                  AppListRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Mon solde',
                    iconColor: AppColors.muted,
                    trailing: Text(
                      _wallet != null
                          ? '${_wallet!.balance.toStringAsFixed(0)} F CFA'
                          : '—',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontSize: 16, height: 1),
                    ),
                    onTap: () => _openWallet(session!.profileId!),
                  ),

                const SizedBox(height: 26),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (_nextAppointment != null) ...[
                    const SectionHeader(title: 'Prochain rendez-vous'),
                    const SizedBox(height: 12),
                    _NextAppointmentCard(
                      appointment: _nextAppointment!,
                      psychologist: _nextAppointmentPsychologist,
                    ),
                    const SizedBox(height: 26),
                  ],

                  if (_pendingRecommendations.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Avant ma prochaine séance',
                      subtitle:
                          '${_pendingRecommendations.length} conseil(s) à cocher',
                    ),
                    const SizedBox(height: 12),
                    ..._pendingRecommendations.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecommendationTile(
                          recommendation: r,
                          onDone: () => _markRecommendationDone(r),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SectionHeader(
                    title: 'Recommandé pour vous',
                    subtitle: 'Sélection personnalisée',
                    actionLabel: 'Voir tout',
                    onAction: widget.onOpenSearch,
                  ),
                  const SizedBox(height: 12),
                  if (_recommended.isEmpty)
                    AppEmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'Aucun psychologue disponible',
                      message:
                          'Revenez dans un moment, ou lancez une recherche '
                          'manuelle.',
                      actionLabel: 'Chercher',
                      onAction: widget.onOpenSearch,
                    )
                  else
                    ...List.generate(_recommended.length, (i) {
                      final p = _recommended[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PsychologistMiniCard(
                          psychologist: p,
                          onTap: () => _openProfile(p.id),
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.greeting,
    required this.name,
    required this.broadcastCount,
    required this.notifCount,
    required this.onOpenAnnouncements,
    required this.onOpenNotifications,
  });

  final String greeting;
  final String name;
  final int broadcastCount;
  final int notifCount;
  final VoidCallback onOpenAnnouncements;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.tealDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          name.isEmpty ? 'Bienvenue' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                _HeroIconButton(
                  icon: Icons.campaign_outlined,
                  tooltip: 'Annonces système',
                  badge: broadcastCount,
                  onTap: onOpenAnnouncements,
                ),
                _HeroIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Notifications',
                  badge: notifCount,
                  onTap: onOpenNotifications,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1),
          ],
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final int badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(
                icon,
                size: 21,
                color: onTap == null ? AppColors.faint : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.emergency,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.emergency_outlined, color: Colors.white, size: 21),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "J'ai besoin d'aide maintenant",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Un psychologue disponible immédiatement',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.recommendation,
    required this.onDone,
  });

  final SessionRecommendation recommendation;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onDone,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      borderColor: AppColors.tealMid,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.radio_button_unchecked,
                color: AppColors.teal, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.content,
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 6),
                const AppPill(
                  label: 'Conseil de votre psychologue',
                  icon: Icons.psychology_outlined,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({required this.appointment, this.psychologist});

  final Appointment appointment;
  final PsychologistProfile? psychologist;

  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final time = '${start.hour.toString().padLeft(2, '0')}h'
        '${start.minute.toString().padLeft(2, '0')}';
    final daysAway = start.difference(DateTime.now()).inDays;
    final relative = daysAway <= 0
        ? "aujourd'hui"
        : daysAway == 1
            ? 'demain'
            : 'dans $daysAway jours';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
          left: BorderSide(color: AppColors.teal, width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Column(
              children: [
                Text(
                  start.day.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 24,
                        color: AppColors.tealDeep,
                        height: 1,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  _months[start.month - 1].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 48, color: AppColors.border),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  psychologist != null ? psychologist!.fullName : 'Psychologue',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$time · $relative',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                AppPill(
                  label: '${appointment.consultationType.label} · '
                      '${appointment.status.label}',
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileReminder extends StatelessWidget {
  const _ProfileReminder({required this.missing, required this.onTap});

  final List<String> missing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 7, right: 21),
                  child: Container(
                    width: 7,
                    height: 7,
                    color: AppColors.goldDark,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complétez votre profil',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Encore à renseigner : ${missing.join(', ')}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Text(
                    'Compléter',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
