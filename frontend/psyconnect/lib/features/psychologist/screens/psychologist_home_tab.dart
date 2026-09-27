import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../../auth/services/profile_service.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/screens/announcements_screen.dart';
import '../../patient/screens/notifications_screen.dart';
import '../../patient/services/appointment_service.dart';
import '../../patient/services/notification_service.dart';
import '../../patient/services/psychologist_service.dart';

class PsychologistHomeTab extends StatefulWidget {
  const PsychologistHomeTab({super.key});

  @override
  State<PsychologistHomeTab> createState() => _PsychologistHomeTabState();
}

class _PsychologistHomeTabState extends State<PsychologistHomeTab> {
  final _appointmentService = AppointmentService();
  final _psychologistService = PsychologistService();
  final _profileService = ProfileService();
  final _notificationService = NotificationService();

  final _api = ApiClient();
  final _storage = const FlutterSecureStorage();

  bool _loading = true;
  String? _error;
  PsychologistProfile? _me;
  List<Appointment> _appointments = [];
  Map<int, PatientProfile> _patientsById = {};
  int _unreadNotifCount = 0;
  int _newBroadcastCount = 0;

  bool _savingEmergency = false;

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
      final me = results[0] as PsychologistProfile;
      final appointments = results[1] as List<Appointment>;
      appointments.sort((a, b) => a.startTime.compareTo(b.startTime));

      final patientIds = appointments.map((a) => a.patientId).toSet();
      final patients =
          await Future.wait(patientIds.map(_safeGetPatientProfile));

      if (!mounted) return;
      setState(() {
        _me = me;
        _appointments = appointments;
        _patientsById = {
          for (final p in patients)
            if (p != null) p.id: p,
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger le tableau de bord.';
        _loading = false;
      });
    }

    unawaited(_refreshUnreadNotifCount());
    unawaited(_refreshBroadcastBadge());
  }

  Future<void> _refreshUnreadNotifCount() async {
    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) return;
    try {
      final notifications =
          await _notificationService.getNotificationsByUserId(psychologistId);
      final unread = notifications.where((n) => !n.isRead).length;
      if (mounted) setState(() => _unreadNotifCount = unread);
    } catch (_) {
    }
  }

  Future<void> _openNotifications(int psychologistId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(userId: psychologistId),
      ),
    );
    if (mounted) _refreshUnreadNotifCount();
  }

  Future<void> _refreshBroadcastBadge() async {
    try {
      final json = await _api.get(ApiConstants.broadcasts);
      final broadcasts = (json as List).cast<Map<String, dynamic>>();

      final lastSeenStr = await _storage.read(key: 'psy_broadcasts_last_seen');
      final lastSeen = lastSeenStr != null
          ? DateTime.tryParse(lastSeenStr) ?? DateTime.fromMillisecondsSinceEpoch(0)
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
    final lastSeenStr = await _storage.read(key: 'psy_broadcasts_last_seen');
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
      key: 'psy_broadcasts_last_seen',
      value: DateTime.now().toIso8601String(),
    );
    if (mounted) _refreshBroadcastBadge();
  }

  Appointment? get _nextAppointment {
    final now = DateTime.now();
    final upcoming = _activeAppointments
        .where((a) => a.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<PatientProfile?> _safeGetPatientProfile(int patientId) async {
    try {
      return await _profileService.getPatientProfileById(patientId);
    } catch (_) {
      return null;
    }
  }

  List<Appointment> get _activeAppointments => _appointments
      .where((a) =>
          a.status != AppointmentStatus.cancelled &&
          a.status != AppointmentStatus.rejected)
      .toList();

  List<Appointment> get _todayAppointments {
    final now = DateTime.now();
    return _activeAppointments
        .where((a) =>
            a.startTime.year == now.year &&
            a.startTime.month == now.month &&
            a.startTime.day == now.day)
        .toList();
  }

  int get _thisWeekCount {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    return _activeAppointments
        .where((a) =>
            !a.startTime.isBefore(monday) && a.startTime.isBefore(nextMonday))
        .length;
  }

  int get _activePatientsCount =>
      _activeAppointments.map((a) => a.patientId).toSet().length;

  Future<void> _updateStatus(Appointment a, AppointmentStatus status) async {
    try {
      await _appointmentService.updateAppointmentStatus(a.id, status);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible. Réessayez.')),
      );
    }
  }

  Future<void> _toggleEmergency() async {
    final me = _me;
    if (me == null || _savingEmergency) return;

    final newAvailable = !me.availableForEmergency;
    setState(() => _savingEmergency = true);

    try {
      final updated = await _psychologistService.toggleEmergencyAvailability(
        me.id,
        available: newAvailable,
        freeSession: newAvailable ? me.offersFreeSessions : false,
      );
      if (!mounted) return;
      setState(() {
        _me = updated;
        _savingEmergency = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newAvailable
                ? 'Mode urgence activé — vous apparaissez dans la liste '
                    'd\'aide immédiate.'
                : 'Mode urgence désactivé.',
          ),
          backgroundColor: newAvailable
              ? AppColors.emergency
              : AppColors.muted,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingEmergency = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException
              ? e.message
              : 'Impossible de mettre à jour le mode urgence.'),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final name = _me != null ? _me!.fullName : (session?.pseudo ?? '');

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.teal,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _PsyHero(
            name: name,
            specialty: _me?.specialty,
            verified: _me?.profileVerified ?? false,
            broadcastCount: _newBroadcastCount,
            notifCount: _unreadNotifCount,
            onOpenAnnouncements: _openAnnouncements,
            onOpenNotifications: session?.profileId == null
                ? null
                : () => _openNotifications(session!.profileId!),
            onLogout: _logout,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_me != null && !_me!.profileVerified) ...[
                  _ApprovalStatusBanner(rejected: _me!.rejected),
                  const SizedBox(height: 16),
                ],

                _EmergencyToggleCard(
                  isAvailable: _me?.availableForEmergency ?? false,
                  offersFreeSessions: _me?.offersFreeSessions ?? false,
                  isSaving: _savingEmergency,
                  onToggle: (_me != null && _me!.profileVerified)
                      ? _toggleEmergency
                      : null,
                ),
                const SizedBox(height: 26),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  AppErrorState(
                    title: 'Tableau de bord indisponible',
                    message: _error!,
                    onRetry: _load,
                  )
                else ...[
                  const SectionHeader(title: 'Mon activité'),
                  const SizedBox(height: 6),
                  StatBand(
                    children: [
                      StatTile(
                        value: '${_todayAppointments.length}',
                        label: "Aujourd'hui",
                      ),
                      StatTile(
                        value: '$_thisWeekCount',
                        label: 'Cette semaine',
                      ),
                      StatTile(
                        value: '$_activePatientsCount',
                        label: 'Patients actifs',
                      ),
                      StatTile(
                        value: _me?.rating != null && _me!.rating! > 0
                            ? _me!.rating!.toStringAsFixed(1)
                            : '—',
                        label: 'Ma note',
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  if (_nextAppointment != null) ...[
                    const SectionHeader(title: 'Prochain rendez-vous'),
                    const SizedBox(height: 12),
                    _NextPatientAppointmentCard(
                      appointment: _nextAppointment!,
                      patient: _patientsById[_nextAppointment!.patientId],
                    ),
                    const SizedBox(height: 26),
                  ],

                  SectionHeader(
                    title: 'Planning du jour',
                    subtitle: _todayAppointments.isEmpty
                        ? null
                        : '${_todayAppointments.length} séance(s) prévue(s)',
                  ),
                  const SizedBox(height: 12),
                  if (_todayAppointments.isEmpty)
                    const AppEmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'Journée libre',
                      message: "Aucun rendez-vous aujourd'hui. "
                          'Profitez-en pour mettre à jour vos disponibilités.',
                    )
                  else
                    ..._todayAppointments.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PlanningCard(
                            appointment: a,
                            patient: _patientsById[a.patientId],
                            onConfirm: () =>
                                _updateStatus(a, AppointmentStatus.confirmed),
                            onReject: () =>
                                _updateStatus(a, AppointmentStatus.rejected),
                          ),
                        )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PsyHero extends StatelessWidget {
  const _PsyHero({
    required this.name,
    required this.specialty,
    required this.verified,
    required this.broadcastCount,
    required this.notifCount,
    required this.onOpenAnnouncements,
    required this.onOpenNotifications,
    required this.onLogout,
  });

  final String name;
  final String? specialty;
  final bool verified;
  final int broadcastCount;
  final int notifCount;
  final VoidCallback onOpenAnnouncements;
  final VoidCallback? onOpenNotifications;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 10, 0),
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
                          [
                            name.isEmpty ? 'Praticien' : name,
                            if (verified) 'Vérifiée',
                          ].join(' · ').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.tealDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Tableau de bord',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        if (specialty?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 5),
                          Text(
                            specialty!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _PsyHeroButton(
                  icon: Icons.campaign_outlined,
                  tooltip: 'Annonces système',
                  badge: broadcastCount,
                  onTap: onOpenAnnouncements,
                ),
                _PsyHeroButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Notifications',
                  badge: notifCount,
                  onTap: onOpenNotifications,
                ),
                _PsyHeroButton(
                  icon: Icons.logout_rounded,
                  tooltip: 'Se déconnecter',
                  badge: 0,
                  onTap: onLogout,
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

class _PsyHeroButton extends StatelessWidget {
  const _PsyHeroButton({
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
          width: 40,
          height: 40,
          child: Center(
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(
                icon,
                size: 20,
                color: onTap == null ? AppColors.faint : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmergencyToggleCard extends StatefulWidget {
  const _EmergencyToggleCard({
    required this.isAvailable,
    required this.offersFreeSessions,
    required this.isSaving,
    required this.onToggle,
  });

  final bool isAvailable;
  final bool offersFreeSessions;
  final bool isSaving;
  final VoidCallback? onToggle;

  @override
  State<_EmergencyToggleCard> createState() => _EmergencyToggleCardState();
}

class _EmergencyToggleCardState extends State<_EmergencyToggleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.isAvailable) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_EmergencyToggleCard old) {
    super.didUpdateWidget(old);
    if (widget.isAvailable && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isAvailable && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isAvailable;
    final saving = widget.isSaving;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: active ? AppColors.emergency : AppColors.white,
        border: Border.all(
          color: active ? AppColors.emergency : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: saving ? null : widget.onToggle,
          splashColor: active
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.emergency.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (active)
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white
                                .withValues(alpha: _pulse.value),
                          ),
                        ),
                      ),
                    if (active) const SizedBox(width: 6),
                    Text(
                      active ? 'EN LIGNE · URGENCES' : 'MODE URGENCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: active
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    if (saving)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: active ? Colors.white : AppColors.teal,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      active
                          ? Icons.emergency_outlined
                          : Icons.do_not_disturb_alt_outlined,
                      color: active ? Colors.white : AppColors.emergency,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active
                                ? 'Disponible maintenant'
                                : 'Non disponible',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: active ? Colors.white : AppColors.text,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            active
                                ? (widget.offersFreeSessions
                                    ? 'Visible dans l\'aide immédiate — consultation gratuite'
                                    : 'Visible dans la liste d\'aide immédiate')
                                : 'Appuyez pour apparaître dans l\'aide immédiate',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: active
                                  ? Colors.white.withValues(alpha: 0.78)
                                  : AppColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.emergency,
                    border: active
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      saving
                          ? 'Mise à jour…'
                          : active
                              ? 'Appuyer pour désactiver'
                              : 'Activer le mode urgence',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

class _ApprovalStatusBanner extends StatelessWidget {
  const _ApprovalStatusBanner({required this.rejected});

  final bool rejected;

  static const _adminEmail = 'admin@psyconnect.sn';
  static const _adminPhone = '+221 78 000 00 00';

  @override
  Widget build(BuildContext context) {
    if (rejected) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.block_outlined, color: AppColors.rose, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Profil refusé par l\'administrateur',
                    style: TextStyle(
                      color: AppColors.rose,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Votre profil n'est pas visible des patients et vous ne "
              'pouvez recevoir aucun rendez-vous. Contactez '
              "l'administration si vous pensez qu'il s'agit d'une erreur :",
              style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text('$_adminEmail · $_adminPhone',
                style: const TextStyle(
                    color: AppColors.rose,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top_outlined, color: AppColors.gold, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil en cours de validation',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Vous n'êtes pas encore visible des patients et ne pouvez "
                  'recevoir de rendez-vous. Vous serez notifié dès que '
                  "l'administrateur aura validé votre profil.",
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextPatientAppointmentCard extends StatelessWidget {
  const _NextPatientAppointmentCard({required this.appointment, this.patient});

  final Appointment appointment;
  final PatientProfile? patient;

  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final time = '${start.hour.toString().padLeft(2, '0')}h'
        '${start.minute.toString().padLeft(2, '0')}';
    final name = patient != null
        ? '${patient!.firstName} ${patient!.lastName}'.trim()
        : 'Patient';
    final daysAway = start.difference(DateTime.now()).inDays;
    final relative = daysAway <= 0
        ? "Aujourd'hui"
        : daysAway == 1
            ? 'Demain'
            : 'Dans $daysAway jours';

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
                  name.isEmpty ? 'Patient' : name,
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
                  '$time · ${relative.toLowerCase()}',
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

class _PlanningCard extends StatelessWidget {
  const _PlanningCard({
    required this.appointment,
    this.patient,
    required this.onConfirm,
    required this.onReject,
  });

  final Appointment appointment;
  final PatientProfile? patient;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final time = '${start.hour.toString().padLeft(2, '0')}h'
        '${start.minute.toString().padLeft(2, '0')}';
    final name = patient != null
        ? '${patient!.firstName} ${patient!.lastName}'.trim()
        : 'Patient';

    final pending = appointment.status == AppointmentStatus.pending;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  time,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 17,
                        color: AppColors.tealDeep,
                        height: 1,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Patient' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    AppPill(
                      label: appointment.consultationType.label,
                      icon: Icons.videocam_outlined,
                      dense: true,
                      color: AppColors.textSecondary,
                      background: AppColors.surfaceAlt,
                    ),
                  ],
                ),
              ),
              if (!pending)
                AppPill(
                  label: appointment.status.label,
                  color: AppColors.teal,
                  background: AppColors.tealLight,
                  dense: true,
                ),
            ],
          ),
          if (pending) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      backgroundColor: AppColors.dangerBg,
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: appointment.startTime.isAfter(DateTime.now())
                        ? onConfirm
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(
                    appointment.startTime.isAfter(DateTime.now())
                        ? 'Confirmer'
                        : 'Date passée',
                  ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
