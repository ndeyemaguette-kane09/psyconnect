import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/services/appointment_service.dart';

/// Contenu de l'onglet "Patients" du parcours psychologue (cf. maquette v2).
///
/// Aucun endpoint backend ne liste "les patients d'un psychologue" : la liste
/// est déduite côté client en dédupliquant les `patientId` présents dans
/// `GET /appointments/psychologist/{id}` (vérifié en lisant
/// AppointmentController — pas d'endpoint dédié), puis en résolvant chaque
/// nom via `GET /patients/{id}`.
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key});

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  final _appointmentService = AppointmentService();
  final _profileService = ProfileService();

  bool _loading = true;
  String? _error;
  List<_PatientEntry> _patients = [];

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text('Mes patients',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off,
                            color: AppColors.muted, size: 36),
                        const SizedBox(height: 8),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                ),
              )
            else if (_patients.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Aucun patient pour le moment.',
                      style: TextStyle(color: AppColors.muted)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverList.separated(
                  itemCount: _patients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _PatientCard(entry: _patients[i]),
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

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.entry});

  final _PatientEntry entry;

  @override
  Widget build(BuildContext context) {
    final profile = entry.profile;
    final name = profile != null
        ? '${profile.firstName} ${profile.lastName}'.trim()
        : 'Patient';
    final last = entry.lastVisit;
    final lastVisitLabel = '${last.day.toString().padLeft(2, '0')}/'
        '${last.month.toString().padLeft(2, '0')}/${last.year}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PatientDetailSheet(entry: entry),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.tealLight,
              child: Icon(Icons.person, color: AppColors.tealDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Patient' : name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.appointmentCount} consultation'
                    '${entry.appointmentCount > 1 ? 's' : ''} · dernière le '
                    '$lastVisitLabel',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Fiche détail d'un patient, ouverte au tap sur une [_PatientCard].
///
/// N'affiche que ce qui existe déjà côté backend (`PatientProfile` +
/// historique des rendez-vous déjà chargé par [_PatientsTabState._load]) —
/// pas de nouvel endpoint nécessaire. Mêmes infos que celles saisies à
/// l'inscription patient (cf. CreatePatientProfileRequest) : antécédents
/// médicaux, contact d'urgence, langue préférée, mode anonyme.
class _PatientDetailSheet extends StatelessWidget {
  const _PatientDetailSheet({required this.entry});

  final _PatientEntry entry;

  @override
  Widget build(BuildContext context) {
    final profile = entry.profile;
    final name = profile != null
        ? '${profile.firstName} ${profile.lastName}'.trim()
        : 'Patient';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.tealMid,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.tealLight,
                    child: Icon(Icons.person,
                        color: AppColors.tealDark, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(name.isEmpty ? 'Patient' : name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                  ),
                  if (profile?.anonymousMode == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.muted.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Mode anonyme',
                          style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionLabel('Informations médicales'),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.medical_information_outlined,
                label: 'Antécédents médicaux',
                value: profile?.medicalHistory,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.language_outlined,
                label: 'Langue préférée',
                value: profile?.preferredLanguage,
              ),
              const SizedBox(height: 20),
              const _SectionLabel("Contact d'urgence"),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.person_pin_outlined,
                label: 'Nom',
                value: profile?.emergencyContactName,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Téléphone',
                value: profile?.emergencyContactPhone,
              ),
              const SizedBox(height: 20),
              _SectionLabel(
                  'Historique des rendez-vous (${entry.visits.length})'),
              const SizedBox(height: 8),
              ...entry.visits.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _VisitRow(appointment: a),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontWeight: FontWeight.w700, color: AppColors.tealDark, fontSize: 13),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                hasValue ? value! : 'Non renseigné',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: hasValue ? AppColors.tealDark : AppColors.muted,
                  fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.appointment});

  final Appointment appointment;

  Color get _statusColor {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return AppColors.gold;
      case AppointmentStatus.confirmed:
        return AppColors.teal;
      case AppointmentStatus.completed:
        return AppColors.muted;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.rejected:
        return AppColors.rose;
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final date = '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')}/${start.year} à '
        '${start.hour.toString().padLeft(2, '0')}h'
        '${start.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealLight.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(date, style: const TextStyle(fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              appointment.status.label,
              style: TextStyle(
                  color: _statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
