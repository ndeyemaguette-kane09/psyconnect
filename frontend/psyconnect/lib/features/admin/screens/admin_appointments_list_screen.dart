import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/services/profile_service.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/services/psychologist_service.dart';
import '../services/admin_service.dart';
import '../widgets/page_controls.dart';

// ecran ouvert depuis l'onglet Stats (clic sur une ligne de
// "Repartition des rendez-vous") — pas dans la maquette v2. liste complete
// des RDV, le filtre est gere par le backend (GET /admin/appointments?status=).
//
// initialStatus pre-selectionne le filtre selon la ligne cliquee, mais on
// peut le changer depuis l'ecran
class AdminAppointmentsListScreen extends StatefulWidget {
  const AdminAppointmentsListScreen({super.key, this.initialStatus});

  final AppointmentStatus? initialStatus;

  @override
  State<AdminAppointmentsListScreen> createState() =>
      _AdminAppointmentsListScreenState();
}

class _AdminAppointmentsListScreenState
    extends State<AdminAppointmentsListScreen> {
  static const _pageSize = 10;

  final _adminService = AdminService();
  final _profileService = ProfileService();
  final _psychologistService = PsychologistService();

  bool _loading = true;
  String? _error;
  List<Appointment> _appointments = [];
  Map<int, PatientProfile> _patientsById = {};
  Map<int, PsychologistProfile> _psychologistsById = {};
  AppointmentStatus? _filter;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialStatus;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appointments =
          await _adminService.listAppointments(status: _filter?.apiValue);
      appointments.sort((a, b) => b.startTime.compareTo(a.startTime));

      final patientIds = appointments.map((a) => a.patientId).toSet();
      final psychologistIds =
          appointments.map((a) => a.psychologistId).toSet();
      final patients = await Future.wait(patientIds.map(_safeGetPatient));
      final psychologists =
          await Future.wait(psychologistIds.map(_safeGetPsychologist));

      if (!mounted) return;
      setState(() {
        _appointments = appointments;
        _patientsById = {
          for (final p in patients) if (p != null) p.id: p,
        };
        _psychologistsById = {
          for (final p in psychologists) if (p != null) p.id: p,
        };
        _page = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les rendez-vous.';
        _loading = false;
      });
    }
  }

  // si un profil est introuvable ou erreur reseau, on ignore plutot que de
  // faire planter tout l'ecran (pareil que dans psychologist_home_tab)
  Future<PatientProfile?> _safeGetPatient(int id) async {
    try {
      return await _profileService.getPatientProfileById(id);
    } catch (_) {
      return null;
    }
  }

  Future<PsychologistProfile?> _safeGetPsychologist(int id) async {
    try {
      return await _psychologistService.getPsychologistById(id);
    } catch (_) {
      return null;
    }
  }

  void _setFilter(AppointmentStatus? status) {
    setState(() => _filter = status);
    _load();
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }

  Color _statusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return AppColors.gold;
      case AppointmentStatus.confirmed:
        return AppColors.teal;
      case AppointmentStatus.completed:
        return AppColors.tealDark;
      case AppointmentStatus.cancelled:
        return AppColors.muted;
      case AppointmentStatus.rejected:
        return AppColors.rose;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Rendez-vous',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Tous'),
                            selected: _filter == null,
                            selectedColor: AppColors.tealLight,
                            onSelected: (_) => _setFilter(null),
                          ),
                        ),
                        for (final s in AppointmentStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(s.label),
                              selected: _filter == s,
                              selectedColor: AppColors.tealLight,
                              onSelected: (_) => _setFilter(s),
                            ),
                          ),
                      ],
                    ),
                  ),
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
              else if (_appointments.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('Aucun rendez-vous dans cette catégorie.',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                )
              else
                _buildPagedList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagedList() {
    final pageCount = pageCountFor(_appointments.length, _pageSize);
    final pageItems = paginate(_appointments, _page, _pageSize);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          for (final a in pageItems) ...[
            _AppointmentRow(
              appointment: a,
              patient: _patientsById[a.patientId],
              psychologist: _psychologistsById[a.psychologistId],
              statusColor: _statusColor(a.status),
              dateLabel: _formatDateTime(a.startTime),
            ),
            const SizedBox(height: 10),
          ],
          PageControls(
            page: _page,
            pageCount: pageCount,
            onPageChanged: (p) => setState(() => _page = p),
          ),
        ]),
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({
    required this.appointment,
    required this.patient,
    required this.psychologist,
    required this.statusColor,
    required this.dateLabel,
  });

  final Appointment appointment;
  final PatientProfile? patient;
  final PsychologistProfile? psychologist;
  final Color statusColor;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final patientName = patient != null
        ? '${patient!.firstName} ${patient!.lastName}'.trim()
        : 'Patient #${appointment.patientId}';
    final psychologistName =
        psychologist != null ? psychologist!.fullName : 'Psy #${appointment.psychologistId}';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: AppColors.tealMid,
      shadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(dateLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                ),
                child: Text(appointment.status.label,
                    style: TextStyle(
                        fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(patientName, style: const TextStyle(fontSize: 13))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(psychologistName, style: const TextStyle(fontSize: 13))),
            ],
          ),
          const SizedBox(height: 4),
          Text(appointment.consultationType.label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}
