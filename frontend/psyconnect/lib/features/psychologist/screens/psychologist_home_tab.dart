import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../../auth/services/profile_service.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/screens/notifications_screen.dart';
import '../../patient/services/appointment_service.dart';
import '../../patient/services/notification_service.dart';
import '../../patient/services/psychologist_service.dart';

/// Contenu de l'onglet "Accueil" du parcours psychologue (cf. maquette v2,
/// "Tableau de Bord Psychologue").
///
/// Écarts assumés par rapport à la maquette, dictés par les limites réelles
/// du backend (aucun endpoint stats/paiement n'existe, vérifié en lisant les
/// contrôleurs Java) :
/// - La carte "Revenus ce mois" est omise : aucun payment-service n'existe,
///   impossible de l'afficher sans inventer un chiffre.
/// - Les 4 stats ("RDV aujourd'hui", "Cette semaine", "Patients actifs",
///   "Ma note") sont calculées côté client à partir de
///   GET /appointments/psychologist/{id} (les 3 premières) et du champ
///   `rating` du PsychologistProfile (la 4e) — pas d'endpoint dédié.
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

  bool _loading = true;
  String? _error;
  PsychologistProfile? _me;
  List<Appointment> _appointments = [];
  Map<int, PatientProfile> _patientsById = {};
  int _unreadNotifCount = 0;

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

    // Lu avant tout `await` : éviter d'utiliser `context` après un gap async.
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
  }

  // Même badge "non lu" que côté patient (cf. ProfileTab) — appel
  // best-effort séparé : une erreur réseau ici ne doit pas empêcher
  // d'afficher le reste du tableau de bord.
  Future<void> _refreshUnreadNotifCount() async {
    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) return;
    try {
      final notifications =
          await _notificationService.getNotificationsByUserId(psychologistId);
      final unread = notifications.where((n) => !n.isRead).length;
      if (mounted) setState(() => _unreadNotifCount = unread);
    } catch (_) {
      // Échec silencieux : le badge garde sa dernière valeur connue.
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

  // Premier rendez-vous futur, pas annulé/refusé, le plus proche — même
  // logique que `_NextAppointmentCard` côté patient (cf.
  // `patient_home_screen.dart`), pour équilibrer les deux parcours.
  Appointment? get _nextAppointment {
    final now = DateTime.now();
    final upcoming = _activeAppointments
        .where((a) => a.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// Best-effort : un patient introuvable/erreur réseau ne doit pas faire
  /// échouer tout le chargement du dashboard.
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

  /// Absente de la maquette (pas d'onglet Profil côté psychologue), ajoutée
  /// car `PsychologistShell` n'offrait jusqu'ici aucun moyen de se
  /// déconnecter (5 onglets, aucun accès profil/paramètres) — cf. mémoire
  /// projet. Même pattern que `ProfileTab`/`HomeScreen` côté patient.
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

/// Même rendu visuel que `_NextAppointmentCard` côté patient (carte
/// dégradée en tête d'écran), avec le nom (ou pseudo, déjà résolu côté
/// backend en mode anonyme) du patient à la place du psychologue.
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
