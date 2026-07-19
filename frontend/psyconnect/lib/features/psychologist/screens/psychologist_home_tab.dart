import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
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

// Onglet Accueil du psychologue. Les revenus sont dans l'onglet Statistiques ;
// les quatre indicateurs du tableau de bord sont calculés depuis la liste des RDV.
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
  // Badge mégaphone : annonces non vues depuis la dernière ouverture.
  int _newBroadcastCount = 0;

  // toggle urgence : état local synchronisé avec le backend
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

    // Lu avant l'await pour éviter d'utiliser context après une opération asynchrone.
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

  // Chargement du badge "non lus", indépendant du reste pour ne pas bloquer l'affichage.
  Future<void> _refreshUnreadNotifCount() async {
    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) return;
    try {
      final notifications =
          await _notificationService.getNotificationsByUserId(psychologistId);
      final unread = notifications.where((n) => !n.isRead).length;
      if (mounted) setState(() => _unreadNotifCount = unread);
    } catch (_) {
      // Échec silencieux : le badge conserve sa dernière valeur.
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
    await _storage.write(
      key: 'psy_broadcasts_last_seen',
      value: DateTime.now().toIso8601String(),
    );
    if (mounted) setState(() => _newBroadcastCount = 0);

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
    );
    if (mounted) _refreshBroadcastBadge();
  }

  // Premier rendez-vous futur non annulé et non refusé.
  Appointment? get _nextAppointment {
    final now = DateTime.now();
    final upcoming = _activeAppointments
        .where((a) => a.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  // Récupère un profil patient sans bloquer le chargement si l'appel échoue.
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

  // toggle le mode urgence : tap sur la carte → inverse l'état courant
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
                ? 'Mode urgence activé — les patients peuvent vous appeler.'
                : 'Mode urgence désactivé.',
          ),
          backgroundColor: newAvailable
              ? const Color(0xFFE53935)
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

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              width: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bonjour',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          name.isEmpty ? '' : name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Annonces système',
                    onPressed: _openAnnouncements,
                    icon: Badge(
                      isLabelVisible: _newBroadcastCount > 0,
                      label: Text('$_newBroadcastCount'),
                      backgroundColor: AppColors.rose,
                      child: const Icon(Icons.campaign_outlined,
                          color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: session?.profileId == null
                        ? null
                        : () => _openNotifications(session!.profileId!),
                    icon: Badge(
                      isLabelVisible: _unreadNotifCount > 0,
                      label: Text('$_unreadNotifCount'),
                      child: const Icon(Icons.notifications_outlined,
                          color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Se déconnecter',
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // carte mode urgence : toujours affichée, même pendant le chargement
            _EmergencyToggleCard(
              isAvailable: _me?.availableForEmergency ?? false,
              offersFreeSessions: _me?.offersFreeSessions ?? false,
              isSaving: _savingEmergency,
              onToggle: _me != null ? _toggleEmergency : null,
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _load, child: const Text('Réessayer')),
                    ],
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  _DashStat(
                      value: '${_todayAppointments.length}',
                      label: "RDV aujourd'hui"),
                  _DashStat(value: '$_thisWeekCount', label: 'Cette semaine'),
                  _DashStat(
                      value: '$_activePatientsCount',
                      label: 'Patients actifs'),
                  _DashStat(
                      value: _me?.rating != null && _me!.rating! > 0
                          ? _me!.rating!.toStringAsFixed(1)
                          : '—',
                      label: 'Ma note'),
                ],
              ),
              const SizedBox(height: 24),
              if (_nextAppointment != null) ...[
                Text('Prochain rendez-vous',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _NextPatientAppointmentCard(
                  appointment: _nextAppointment!,
                  patient: _patientsById[_nextAppointment!.patientId],
                ),
                const SizedBox(height: 24),
              ],
              Text('Planning du jour',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (_todayAppointments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text("Aucun rendez-vous aujourd'hui.",
                      style: const TextStyle(color: AppColors.muted)),
                )
              else
                ..._todayAppointments.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
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
    );
  }
}

// Carte de disponibilité urgence, toujours visible. Un tap bascule le mode.
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
        borderRadius: BorderRadius.circular(18),
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: active ? null : AppColors.white,
        border: Border.all(
          color: active
              ? const Color(0xFFB71C1C)
              : AppColors.tealMid,
          width: active ? 0 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                )
              ]
            : [
                BoxShadow(
                  color: AppColors.text.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: saving ? null : widget.onToggle,
          borderRadius: BorderRadius.circular(18),
          splashColor: active
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFFE53935).withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Indicateur pulsant quand actif
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
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFFE53935).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        active
                            ? Icons.emergency_outlined
                            : Icons.do_not_disturb_alt_outlined,
                        color: active ? Colors.white : const Color(0xFFE53935),
                        size: 24,
                      ),
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
                                    ? 'Les patients peuvent vous appeler — consultation gratuite'
                                    : 'Les patients peuvent vous appeler immédiatement')
                                : 'Appuyez pour vous rendre disponible',
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
                // Bouton d'action pleine largeur
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(10),
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

class _DashStat extends StatelessWidget {
  const _DashStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.tealDark)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// Carte du prochain rendez-vous, côté psychologue : affiche le nom du patient
// (ou son pseudo si le mode anonyme est activé, géré côté backend).
class _NextPatientAppointmentCard extends StatelessWidget {
  const _NextPatientAppointmentCard({required this.appointment, this.patient});

  final Appointment appointment;
  final PatientProfile? patient;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final date = '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')} à '
        '${start.hour.toString().padLeft(2, '0')}h'
        '${start.minute.toString().padLeft(2, '0')}';
    final name = patient != null
        ? '${patient!.firstName} ${patient!.lastName}'.trim()
        : 'Patient';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.event_available, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Patient' : name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date · ${appointment.consultationType.label} · '
                  '${appointment.status.label}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tealMid),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text(time,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.tealDark)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Patient' : name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(appointment.consultationType.label,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                if (appointment.status == AppointmentStatus.pending) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onReject,
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.rose,
                            padding: EdgeInsets.zero),
                        child: const Text('Refuser'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text('Confirmer'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (appointment.status != AppointmentStatus.pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                appointment.status.label,
                style: const TextStyle(
                    color: AppColors.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
