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
    this.onOpenAppointments,
  });

  final VoidCallback onOpenSearch;

  final VoidCallback onOpenProfile;

  final VoidCallback? onOpenAppointments;

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
    final profileId = session?.profileId;

    final displayName =
        (_patientProfile?.firstName.trim().isNotEmpty ?? false)
            ? _patientProfile!.firstName.trim()
            : (session?.pseudo ?? '');

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
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
                  onOpenNotifications: profileId == null
                      ? null
                      : () => _openNotifications(profileId),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        if (_nextAppointment != null) ...[
                          _NextAppointmentPanel(
                            appointment: _nextAppointment!,
                            psychologist: _nextAppointmentPsychologist,
                            onOpen: widget.onOpenAppointments,
                          ),
                          const SizedBox(height: 14),
                        ],
                        _HomeEntry(
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: AppColors.goldDark,
                          iconBackground: AppColors.goldLight,
                          title: 'Parler à Xalaat',
                          subtitle: 'Confidentiel et éphémère, à toute heure',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const XalaatScreen()),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_missingProfileFields.isNotEmpty) ...[
                          _ProfileReminder(
                            missing: _missingProfileFields,
                            onTap: _onIncompleteProfileTap,
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_pendingRecommendations.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SectionHeader(
                            title: 'Avant ma prochaine séance',
                            subtitle:
                                '${_pendingRecommendations.length} conseil(s) à cocher',
                          ),
                          const SizedBox(height: 10),
                          ..._pendingRecommendations.map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RecommendationTile(
                                recommendation: r,
                                onDone: () => _markRecommendationDone(r),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Column(
                            children: [
                              _HomeRow(
                                icon: Icons.book_outlined,
                                title: 'Mon journal',
                                subtitle: 'Noter mon humeur du jour',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const JournalScreen()),
                                ),
                              ),
                              if (profileId != null)
                                _HomeRow(
                                  icon: Icons.account_balance_wallet_outlined,
                                  title: 'Mon solde',
                                  trailing: Text(
                                    _wallet != null
                                        ? '${_wallet!.balance.toStringAsFixed(0)} F'
                                        : '—',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  onTap: () => _openWallet(profileId),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SectionHeader(
                          title: 'Recommandé pour vous',
                          actionLabel: 'Voir tout',
                          onAction: widget.onOpenSearch,
                        ),
                        const SizedBox(height: 10),
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
                          AppCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Column(
                              children: [
                                for (final p in _recommended)
                                  PsychologistMiniCard(
                                    psychologist: p,
                                    onTap: () => _openProfile(p.id),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: _SosButton(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmergencyScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

const _weekdays = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
];

const _monthNames = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

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
    final now = DateTime.now();
    final date =
        '${_weekdays[now.weekday - 1]} ${now.day} ${_monthNames[now.month - 1]}';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name.isEmpty ? greeting : '$greeting $name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Prenez le temps qu'il vous faut. On est là quand vous "
                      'en avez besoin.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _HeroIconButton(
              icon: Icons.campaign_outlined,
              tooltip: 'Annonces',
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
          width: 44,
          height: 44,
          child: Center(
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(
                icon,
                size: 23,
                color: onTap == null ? AppColors.faint : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeEntry extends StatelessWidget {
  const _HomeEntry({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.muted, size: 22),
        ],
      ),
    );
  }
}

class _HomeRow extends StatelessWidget {
  const _HomeRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.teal, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted, size: 22),
          ],
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
      color: AppColors.dangerBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.emergency,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(19),
                    bottom: Radius.circular(6),
                  ),
                ),
                child: const Icon(Icons.phone_outlined,
                    color: Colors.white, size: 19),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "J'ai besoin d'aide maintenant",
                      style: TextStyle(
                        color: Color(0xFF7E3519),
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Un psychologue disponible immédiatement',
                      style: TextStyle(color: Color(0xFF7E3519), fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF7E3519), size: 22),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  style: const TextStyle(fontSize: 15, height: 1.45),
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

class _NextAppointmentPanel extends StatelessWidget {
  const _NextAppointmentPanel({
    required this.appointment,
    this.psychologist,
    this.onOpen,
  });

  final Appointment appointment;
  final PsychologistProfile? psychologist;
  final VoidCallback? onOpen;

  static const _soft = Color(0xFFC9DCD2);

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final time = start.minute == 0
        ? '${start.hour} h'
        : '${start.hour} h ${start.minute.toString().padLeft(2, '0')}';
    final daysAway = DateTime(start.year, start.month, start.day)
        .difference(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day))
        .inDays;
    final relative = daysAway <= 0
        ? "aujourd'hui"
        : daysAway == 1
            ? 'demain'
            : 'dans $daysAway jours';
    final name = psychologist?.fullName ?? 'votre psychologue';

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre prochaine séance, $relative',
            style: const TextStyle(
              color: _soft,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AppAvatar(name: name, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weekdays[start.weekday - 1]} ${start.day} '
                      '${_monthNames[start.month - 1]}, $time',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'avec $name · ${appointment.consultationType.label}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE3EDE7),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.status.label,
                      style: const TextStyle(
                        color: _soft,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onOpen != null) ...[
            const SizedBox(height: 16),
            Material(
              color: AppColors.background,
              shape: const StadiumBorder(),
              child: InkWell(
                onTap: onOpen,
                customBorder: const StadiumBorder(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  child: Text(
                    'Voir mes séances',
                    style: TextStyle(
                      color: AppColors.teal,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    return Material(
      color: AppColors.goldLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 12),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complétez votre profil',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Encore à renseigner : ${missing.join(', ')}.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.goldDark, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
