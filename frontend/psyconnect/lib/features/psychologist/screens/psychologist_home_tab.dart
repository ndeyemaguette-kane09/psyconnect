import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/screens/announcements_screen.dart';
import '../../patient/screens/notifications_screen.dart';
import '../../patient/services/appointment_service.dart';
import '../../patient/services/notification_service.dart';
import '../../patient/services/psychologist_service.dart';
import '../utils/patient_name.dart';

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

  List<Appointment> get _pendingRequests {
    final now = DateTime.now();
    return _appointments
        .where((a) =>
            a.status == AppointmentStatus.pending && a.startTime.isAfter(now))
        .toList();
  }

  String _patientName(int patientId) {
    return patientDisplayName(_patientsById[patientId]);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final firstName = _me != null && _me!.firstName.trim().isNotEmpty
        ? _me!.firstName.trim()
        : (session?.pseudo ?? '');
    final profileId = session?.profileId;
    final next = _nextAppointment;
    final pending = _pendingRequests;
    final today = _todayAppointments
        .where((a) => a.status != AppointmentStatus.pending)
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.teal,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _PsyHero(
            firstName: firstName,
            specialty: _me?.specialty,
            verified: _me?.profileVerified ?? false,
            broadcastCount: _newBroadcastCount,
            notifCount: _unreadNotifCount,
            onOpenAnnouncements: _openAnnouncements,
            onOpenNotifications:
                profileId == null ? null : () => _openNotifications(profileId),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_me != null && !_me!.profileVerified) ...[
                  _ApprovalStatusBanner(rejected: _me!.rejected),
                  const SizedBox(height: 14),
                ],
                _EmergencyRow(
                  isAvailable: _me?.availableForEmergency ?? false,
                  offersFreeSessions: _me?.offersFreeSessions ?? false,
                  isSaving: _savingEmergency,
                  onToggle: (_me != null && _me!.profileVerified)
                      ? _toggleEmergency
                      : null,
                ),
                const SizedBox(height: 14),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  AppErrorState(
                    title: 'Accueil indisponible',
                    message: _error!,
                    onRetry: _load,
                  )
                else ...[
                  if (next != null) ...[
                    _NextConsultationPanel(
                      appointment: next,
                      patientName: _patientName(next.patientId),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (pending.isNotEmpty) ...[
                    const SectionHeader(
                      title: 'À traiter',
                      padding: EdgeInsets.symmetric(horizontal: 4),
                    ),
                    const SizedBox(height: 10),
                    for (final a in pending)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RequestCard(
                          appointment: a,
                          patientName: _patientName(a.patientId),
                          onConfirm: () =>
                              _updateStatus(a, AppointmentStatus.confirmed),
                          onReject: () =>
                              _updateStatus(a, AppointmentStatus.rejected),
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                  const SectionHeader(
                    title: 'Aujourd\'hui',
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  const SizedBox(height: 10),
                  if (today.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Journée libre. Profitez-en pour mettre à jour vos '
                        'disponibilités.',
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.5,
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  else
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Column(
                        children: [
                          for (final a in today)
                            _TodayRow(
                              appointment: a,
                              patientName: _patientName(a.patientId),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 26),
                  const SectionHeader(
                    title: 'Cette semaine',
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: _thisWeekCount <= 1
                                ? '$_thisWeekCount consultation'
                                : '$_thisWeekCount consultations',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const TextSpan(text: ' prévue(s), '),
                          TextSpan(
                            text: _activePatientsCount <= 1
                                ? '$_activePatientsCount patient'
                                : '$_activePatientsCount patients',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          TextSpan(
                            text: _me?.rating != null && _me!.rating! > 0
                                ? ' suivi(s), note moyenne de '
                                    '${_me!.rating!.toStringAsFixed(1).replaceAll('.', ',')}.'
                                : ' suivi(s), pas encore d\'avis reçu.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

String _hour(DateTime d) => d.minute == 0
    ? '${d.hour} h'
    : '${d.hour} h ${d.minute.toString().padLeft(2, '0')}';

class _PsyHero extends StatelessWidget {
  const _PsyHero({
    required this.firstName,
    required this.specialty,
    required this.verified,
    required this.broadcastCount,
    required this.notifCount,
    required this.onOpenAnnouncements,
    required this.onOpenNotifications,
  });

  final String firstName;
  final String? specialty;
  final bool verified;
  final int broadcastCount;
  final int notifCount;
  final VoidCallback onOpenAnnouncements;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Bonjour'
        : hour < 18
            ? 'Bon après-midi'
            : 'Bonsoir';

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
                      '${_weekdays[now.weekday - 1]} ${now.day} '
                      '${_monthNames[now.month - 1]}',
                      style:
                          const TextStyle(fontSize: 15, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      firstName.isEmpty ? greeting : '$greeting $firstName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.muted),
                        children: [
                          if (specialty?.isNotEmpty ?? false)
                            TextSpan(text: specialty),
                          if (verified) ...[
                            if (specialty?.isNotEmpty ?? false)
                              const TextSpan(text: ' · '),
                            const TextSpan(
                              text: 'profil vérifié',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w700,
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
            _PsyHeroButton(
              icon: Icons.campaign_outlined,
              tooltip: 'Annonces',
              badge: broadcastCount,
              onTap: onOpenAnnouncements,
            ),
            _PsyHeroButton(
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

class _EmergencyRow extends StatelessWidget {
  const _EmergencyRow({
    required this.isAvailable,
    required this.offersFreeSessions,
    required this.isSaving,
    required this.onToggle,
  });

  final bool isAvailable;
  final bool offersFreeSessions;
  final bool isSaving;
  final VoidCallback? onToggle;

  static const _ink = Color(0xFF7E3519);

  @override
  Widget build(BuildContext context) {
    final active = isAvailable;
    return Material(
      color: active ? AppColors.dangerBg : AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isSaving ? null : onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: active ? AppColors.emergency : AppColors.borderStrong,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active
                          ? 'Disponible pour les urgences'
                          : 'Urgences : non disponible',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: active ? _ink : AppColors.text,
                      ),
                    ),
                    Text(
                      isSaving
                          ? 'Mise à jour…'
                          : active
                              ? (offersFreeSessions
                                  ? 'Visible dans l\'aide immédiate, séance gratuite'
                                  : 'Vous apparaissez dans l\'aide immédiate')
                              : 'Activez pour apparaître dans l\'aide immédiate',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: active ? _ink : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: active,
                activeTrackColor: AppColors.emergency,
                onChanged: (onToggle == null || isSaving)
                    ? null
                    : (_) => onToggle!(),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rejected ? AppColors.dangerBg : AppColors.goldLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rejected
                ? 'Profil refusé par l\'équipe PsyConnect'
                : 'Profil en cours de validation',
            style: TextStyle(
              color: rejected ? AppColors.danger : AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rejected
                ? 'Votre profil n\'est pas visible des patients et vous ne '
                    'pouvez recevoir aucun rendez-vous. Écrivez-nous si vous '
                    'pensez qu\'il s\'agit d\'une erreur :'
                : 'Vous n\'êtes pas encore visible des patients. Vous serez '
                    'notifié dès que l\'équipe aura validé votre profil.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (rejected) ...[
            const SizedBox(height: 6),
            const Text(
              '$_adminEmail · $_adminPhone',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextConsultationPanel extends StatelessWidget {
  const _NextConsultationPanel({
    required this.appointment,
    required this.patientName,
  });

  final Appointment appointment;
  final String patientName;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final now = DateTime.now();
    final days = DateTime(start.year, start.month, start.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final relative = days <= 0
        ? "aujourd'hui"
        : days == 1
            ? 'demain'
            : 'dans $days jours';

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre prochaine consultation, $relative',
            style: const TextStyle(
              color: Color(0xFFC9DCD2),
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              AppAvatar(name: patientName, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weekdays[start.weekday - 1]} ${start.day} '
                      '${_monthNames[start.month - 1]}, ${_hour(start)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$patientName · ${appointment.consultationType.label}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE3EDE7),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.status.label,
                      style: const TextStyle(
                        color: Color(0xFFC9DCD2),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.appointment,
    required this.patientName,
    required this.onConfirm,
    required this.onReject,
  });

  final Appointment appointment;
  final String patientName;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(name: patientName, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      'Demande pour ${_weekdays[start.weekday - 1].toLowerCase()} '
                      '${start.day}, ${_hour(start)} · '
                      '${appointment.consultationType.label}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  child: const Text('Accepter'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onReject,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sand,
                    foregroundColor: AppColors.text,
                  ),
                  child: const Text('Refuser'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.appointment, required this.patientName});

  final Appointment appointment;
  final String patientName;

  @override
  Widget build(BuildContext context) {
    final status = appointment.status;
    final solid = status == AppointmentStatus.confirmed
        ? AppColors.teal
        : status == AppointmentStatus.completed
            ? AppColors.muted
            : AppColors.goldDark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _hour(appointment.startTime),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  appointment.consultationType.label,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: solid,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
