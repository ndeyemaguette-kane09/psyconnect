import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/screens/medical_history_screen.dart';
import '../../messaging/screens/chat_screen.dart';
import '../../messaging/services/messaging_service.dart';
import '../../patient/services/appointment_service.dart';
import '../utils/patient_name.dart';
import '../services/psy_patient_link_service.dart';
import 'clinical_notes_screen.dart';
import 'patient_questionnaires_screen.dart';

class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key});

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  final _appointmentService = AppointmentService();
  final _profileService = ProfileService();
  final _linkService = PsyPatientLinkService();

  bool _loading = true;
  String? _error;
  List<_PatientEntry> _patients = [];
  Set<int> _followedIds = {};

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
      final appointments = await _appointmentService
          .getAppointmentsByPsychologistId(psychologistId);

      final byPatient = <int, List<Appointment>>{};
      for (final a in appointments) {
        byPatient.putIfAbsent(a.patientId, () => []).add(a);
      }

      final profiles = await Future.wait(
        byPatient.keys.map(_safeGetPatientProfile),
      );
      final profilesById = {
        for (final p in profiles)
          if (p != null) p.id: p,
      };

      final entries = byPatient.entries.map((e) {
        final visits = e.value..sort((a, b) => b.startTime.compareTo(a.startTime));
        return _PatientEntry(
          patientId: e.key,
          profile: profilesById[e.key],
          appointmentCount: visits.length,
          lastVisit: visits.first.startTime,
          visits: visits,
        );
      }).toList()
        ..sort((a, b) => b.lastVisit.compareTo(a.lastVisit));

      if (!mounted) return;
      setState(() {
        _patients = entries;
        _loading = false;
      });

      try {
        final followed = await _linkService.getFollowedPatientIds(psychologistId);
        if (!mounted) return;
        setState(() => _followedIds = followed.toSet());
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger vos patients.';
        _loading = false;
      });
    }
  }

  Future<PatientProfile?> _safeGetPatientProfile(int patientId) async {
    try {
      return await _profileService.getPatientProfileById(patientId);
    } catch (_) {
      return null;
    }
  }

  void _openPatient(_PatientEntry entry) {
    final psychologistId =
        context.read<AuthProvider>().session?.profileId ?? 0;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PatientPage(
        entry: entry,
        isFollowed: _followedIds.contains(entry.patientId),
        psychologistId: psychologistId,
        onFollowChanged: (followed) => setState(() {
          if (followed) {
            _followedIds = {..._followedIds, entry.patientId};
          } else {
            _followedIds =
                _followedIds.where((id) => id != entry.patientId).toSet();
          }
        }),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final followedCount =
        _patients.where((e) => _followedIds.contains(e.patientId)).length;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Mes patients',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
              ),
            ),
            if (!_loading && _error == null && _patients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  '${_patients.length} patient${_patients.length > 1 ? 's' : ''}'
                  ' · $followedCount suivi${followedCount > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else if (_patients.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Aucun patient pour le moment. Ils apparaîtront ici après '
                  'leur première demande de rendez-vous.',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
              )
            else
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final entry in _patients)
                      _PatientRow(
                        entry: entry,
                        isFollowed: _followedIds.contains(entry.patientId),
                        onTap: () => _openPatient(entry),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PatientEntry {
  const _PatientEntry({
    required this.patientId,
    this.profile,
    required this.appointmentCount,
    required this.lastVisit,
    required this.visits,
  });

  final int patientId;
  final PatientProfile? profile;
  final int appointmentCount;
  final DateTime lastVisit;
  final List<Appointment> visits;
}

const _kWeekdayNames = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
];

const _kMonthNames = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

const _kMonthShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _hour(DateTime d) => d.minute == 0
    ? '${d.hour} h'
    : '${d.hour} h ${d.minute.toString().padLeft(2, '0')}';

Color _statusColor(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.pending:
      return AppColors.goldDark;
    case AppointmentStatus.confirmed:
      return AppColors.teal;
    case AppointmentStatus.completed:
      return AppColors.muted;
    case AppointmentStatus.cancelled:
    case AppointmentStatus.rejected:
      return AppColors.danger;
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({
    required this.entry,
    required this.isFollowed,
    required this.onTap,
  });

  final _PatientEntry entry;
  final bool isFollowed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = patientDisplayName(entry.profile);
    final last = entry.lastVisit;
    final count = entry.appointmentCount;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            AppAvatar(name: name, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '$count consultation${count > 1 ? 's' : ''} · dernière le '
                    '${last.day} ${_kMonthShort[last.month - 1]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (isFollowed)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'Suivi',
                  style: TextStyle(
                    color: AppColors.teal,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _PatientPage extends StatefulWidget {
  const _PatientPage({
    required this.entry,
    required this.isFollowed,
    required this.psychologistId,
    required this.onFollowChanged,
  });

  final _PatientEntry entry;
  final bool isFollowed;
  final int psychologistId;
  final ValueChanged<bool> onFollowChanged;

  @override
  State<_PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<_PatientPage> {
  final _linkService = PsyPatientLinkService();
  final _messagingService = MessagingService();
  late bool _followed;
  bool _toggling = false;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _followed = widget.isFollowed;
  }

  Future<void> _toggleFollow() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      if (_followed) {
        await _linkService.unfollowPatient(
            widget.psychologistId, widget.entry.patientId);
        if (!mounted) return;
        setState(() => _followed = false);
        widget.onFollowChanged(false);
      } else {
        await _linkService.followPatient(
            widget.psychologistId, widget.entry.patientId);
        if (!mounted) return;
        setState(() => _followed = true);
        widget.onFollowChanged(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _openChat(String name) async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final conversation = await _messagingService
          .startOrGetConversation(widget.entry.patientId);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          otherDisplayName: name,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la discussion.')),
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final profile = entry.profile;
    final name = patientDisplayName(profile);
    final anonymous = profile?.anonymousMode == true;
    final first = entry.visits.last.startTime;
    final count = entry.appointmentCount;
    final language = profile?.preferredLanguage?.trim() ?? '';
    final contactName = profile?.emergencyContactName?.trim() ?? '';
    final contactPhone = profile?.emergencyContactPhone?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                AppAvatar(name: name, size: 70),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Patient depuis ${_kMonthNames[first.month - 1]} '
                        '${first.year} · $count consultation'
                        '${count > 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.muted),
                      ),
                      if (anonymous)
                        const Text(
                          'Mode anonyme : pseudonyme choisi par le patient',
                          style:
                              TextStyle(fontSize: 15, color: AppColors.muted),
                        )
                      else if (language.isNotEmpty)
                        Text(
                          'Parle $language',
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _openingChat ? null : () => _openChat(name),
                  child: const Text('Écrire'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => _push(PatientQuestionnairesScreen(
                    patientId: entry.patientId,
                    patientName: name,
                  )),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.text,
                  ),
                  child: const Text('Envoyer un questionnaire'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _Heading('Son suivi'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _LinkRow(
                  icon: Icons.edit_note_outlined,
                  tint: AppColors.tealLight,
                  ink: AppColors.teal,
                  title: 'Mes notes cliniques',
                  subtitle: 'Visibles par vous seule',
                  onTap: () => _push(ClinicalNotesScreen(
                    patientId: entry.patientId,
                    patientName: name,
                  )),
                ),
                _LinkRow(
                  icon: Icons.assignment_outlined,
                  tint: AppColors.goldLight,
                  ink: AppColors.goldDark,
                  title: 'Questionnaires',
                  subtitle: 'Historique des scores PHQ-9 et GAD-7',
                  onTap: () => _push(PatientQuestionnairesScreen(
                    patientId: entry.patientId,
                    patientName: name,
                  )),
                ),
                _LinkRow(
                  icon: Icons.medical_information_outlined,
                  tint: AppColors.sand,
                  ink: AppColors.text,
                  title: 'Antécédents médicaux',
                  onTap: () => _push(MedicalHistoryScreen(
                    patientId: entry.patientId,
                    patientName: name,
                  )),
                ),
              ],
            ),
          ),
          if (!anonymous) ...[
            const SizedBox(height: 26),
            const _Heading('Contact d\'urgence'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: contactName.isEmpty && contactPhone.isEmpty
                  ? const Text(
                      'Non renseigné par le patient',
                      style: TextStyle(fontSize: 15.5, color: AppColors.muted),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contactName.isNotEmpty)
                          Text(
                            contactName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        if (contactPhone.isNotEmpty)
                          Text(
                            contactPhone,
                            style: const TextStyle(
                                fontSize: 15, color: AppColors.muted),
                          ),
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 26),
          const _Heading('Consultations'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final a in entry.visits)
                  _VisitRow(
                    appointment: a,
                    isFirst: identical(a, entry.visits.last),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _toggling ? null : _toggleFollow,
              style: TextButton.styleFrom(
                foregroundColor: _followed ? AppColors.danger : AppColors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              child: Text(
                _toggling
                    ? 'Mise à jour…'
                    : _followed
                        ? 'Retirer de mon suivi'
                        : 'Ajouter à mon suivi',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final String title;
  final String? subtitle;
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
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.appointment, required this.isFirst});

  final Appointment appointment;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final past = appointment.status == AppointmentStatus.completed ||
        appointment.status == AppointmentStatus.cancelled ||
        appointment.status == AppointmentStatus.rejected;
    final ink = past ? AppColors.muted : AppColors.teal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 54,
            decoration: BoxDecoration(
              color: past ? AppColors.surfaceAlt : AppColors.tealLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(23),
                bottom: Radius.circular(7),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                Text(
                  start.day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: ink,
                  ),
                ),
                Text(
                  _kMonthShort[start.month - 1],
                  style: TextStyle(fontSize: 11, color: ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_kWeekdayNames[start.weekday - 1]}, ${_hour(start)} · '
                  '${appointment.consultationType.label.toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (isFirst)
                  const Text(
                    'Première consultation',
                    style: TextStyle(fontSize: 13.5, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(appointment.status),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              appointment.status.label,
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
