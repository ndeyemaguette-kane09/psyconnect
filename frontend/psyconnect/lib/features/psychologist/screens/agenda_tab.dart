import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../call/screens/call_screen.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/services/appointment_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/services/payment_service.dart';
import 'session_recommendations_screen.dart';

// Onglet Agenda du psychologue : tous les rendez-vous, avec possibilité
// de confirmer ou refuser ceux en attente.
class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  final _appointmentService = AppointmentService();
  final _profileService = ProfileService();

  bool _loading = true;
  String? _error;
  List<Appointment> _appointments = [];
  Map<int, PatientProfile> _patientsById = {};

  // Filtre par statut. null = "Tous" (vue groupée par statut).
  AppointmentStatus? _statusFilter;

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
      // Les RDV les plus proches en premier.
      appointments.sort((a, b) => a.startTime.compareTo(b.startTime));

      final patientIds = appointments.map((a) => a.patientId).toSet();
      final patients =
          await Future.wait(patientIds.map(_safeGetPatientProfile));

      if (!mounted) return;
      setState(() {
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
        _error = 'Impossible de charger votre agenda.';
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

  // Les RDV en attente apparaissent en tête de liste.
  static const _groupOrder = [
    AppointmentStatus.pending,
    AppointmentStatus.confirmed,
    AppointmentStatus.completed,
    AppointmentStatus.cancelled,
    AppointmentStatus.rejected,
  ];

  void _joinCall(Appointment a) {
    final patient = _patientsById[a.patientId];
    // si mode anonyme : on affiche juste "Patient" pour ne pas exposer le nom
    final name = patient?.anonymousMode == true
        ? 'Patient'
        : patient != null
            ? '${patient.firstName} ${patient.lastName}'.trim()
            : 'Patient';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallScreen(
        appointmentId: a.id,
        peerName: name.isEmpty ? 'Patient' : name,
        isVideo: a.consultationType == ConsultationType.video,
      ),
    ));
  }

  Widget _buildCard(Appointment a) {
    // bouton "Rejoindre" : RDV confirmé + video/audio + fenêtre temporelle ouverte
    // (10 min avant le début jusqu'à 30 min après la fin, pour absorber les retards)
    final now = DateTime.now();
    final callWindowOpen =
        now.isAfter(a.startTime.subtract(const Duration(minutes: 10))) &&
        now.isBefore(a.endTime.add(const Duration(minutes: 30)));
    final canJoinCall = a.status == AppointmentStatus.confirmed &&
        (a.consultationType == ConsultationType.video ||
            a.consultationType == ConsultationType.audio) &&
        callWindowOpen;

    return _AgendaCard(
      appointment: a,
      patient: _patientsById[a.patientId],
      onConfirm: () => _updateStatus(a, AppointmentStatus.confirmed),
      onReject: () => _updateStatus(a, AppointmentStatus.rejected),
      onJoinCall: canJoinCall ? () => _joinCall(a) : null,
    );
  }

  // Liste plate si un filtre est actif, sections groupées par statut sinon.
  List<Widget> _buildContentSlivers() {
    if (_statusFilter != null) {
      final filtered =
          _appointments.where((a) => a.status == _statusFilter).toList();
      if (filtered.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Aucun rendez-vous "${_statusFilter!.label}".',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildCard(filtered[i]),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    for (final status in _groupOrder) {
      final items = _appointments.where((a) => a.status == status).toList();
      if (items.isEmpty) continue;
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${status.label} (${items.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.muted),
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildCard(items[i]),
          ),
        ),
      );
    }
    return slivers;
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
                child: Text('Agenda',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
            ),
            if (!_loading && _error == null && _appointments.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 0, 8),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 20),
                      itemCount: _groupOrder.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final status = i == 0 ? null : _groupOrder[i - 1];
                        final label = status?.label ?? 'Tous';
                        final selected = _statusFilter == status;
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _statusFilter = status),
                          selectedColor: AppColors.teal,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                                color: selected
                                    ? AppColors.teal
                                    : AppColors.tealMid),
                          ),
                        );
                      },
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
            else if (_appointments.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Aucun rendez-vous pour le moment.',
                      style: TextStyle(color: AppColors.muted)),
                ),
              )
            else
              ..._buildContentSlivers(),
          ],
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({
    required this.appointment,
    this.patient,
    required this.onConfirm,
    required this.onReject,
    this.onJoinCall,
  });

  final Appointment appointment;
  final PatientProfile? patient;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  // non-null uniquement pour les RDV confirmés video/audio
  final VoidCallback? onJoinCall;

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
    final name = patient != null
        ? '${patient!.firstName} ${patient!.lastName}'.trim()
        : 'Patient';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AppointmentDetailSheet(
          appointment: appointment,
          patient: patient,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.tealLight,
                  child: Icon(
                    appointment.consultationType == ConsultationType.video
                        ? Icons.videocam_outlined
                        : appointment.consultationType ==
                                ConsultationType.audio
                            ? Icons.call_outlined
                            : Icons.meeting_room_outlined,
                    color: AppColors.teal,
                  ),
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
                        '$date · ${appointment.consultationType.label}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: AppColors.muted, size: 20),
              ],
            ),
            if (appointment.status == AppointmentStatus.pending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.rose),
                          foregroundColor: AppColors.rose),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal),
                      child: const Text('Confirmer'),
                    ),
                  ),
                ],
              ),
            ],
            // bouton appel video/audio pour les RDV confirmes
            if (onJoinCall != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onJoinCall,
                  icon: Icon(
                    appointment.consultationType == ConsultationType.video
                        ? Icons.video_call_outlined
                        : Icons.call_outlined,
                  ),
                  label: Text(
                    appointment.consultationType == ConsultationType.video
                        ? 'Rejoindre l\'appel vidéo'
                        : 'Rejoindre l\'appel audio',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.tealDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Fiche détail d'un rendez-vous : nom du patient (ou pseudo), date, type et paiement.
// Le paiement est chargé à la demande pour ne pas alourdir le _load principal.
class _AppointmentDetailSheet extends StatefulWidget {
  const _AppointmentDetailSheet({required this.appointment, this.patient});

  final Appointment appointment;
  final PatientProfile? patient;

  @override
  State<_AppointmentDetailSheet> createState() =>
      _AppointmentDetailSheetState();
}

class _AppointmentDetailSheetState extends State<_AppointmentDetailSheet> {
  final _paymentService = PaymentService();
  bool _loadingPayment = true;
  Payment? _payment;

  @override
  void initState() {
    super.initState();
    _loadPayment();
  }

  Future<void> _loadPayment() async {
    try {
      final payments = await _paymentService
          .getPaymentsByAppointmentId(widget.appointment.id);
      final completed = payments
          .where((p) => p.status == PaymentStatus.completed)
          .toList();
      if (!mounted) return;
      setState(() {
        _payment = completed.isNotEmpty ? completed.first : null;
        _loadingPayment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPayment = false);
    }
  }

  String _formatXof(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '$buffer FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final patient = widget.patient;
    final name = patient != null
        ? '${patient.firstName} ${patient.lastName}'.trim()
        : 'Patient';
    final start = appointment.startTime;
    final end = appointment.endTime;
    final date = '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')}/${start.year}';
    final timeRange = '${start.hour.toString().padLeft(2, '0')}h'
        '${start.minute.toString().padLeft(2, '0')} – '
        '${end.hour.toString().padLeft(2, '0')}h'
        '${end.minute.toString().padLeft(2, '0')}';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
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
                  if (patient?.anonymousMode == true)
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
              _DetailRow(
                  icon: Icons.event_outlined, label: 'Date', value: date),
              const SizedBox(height: 10),
              _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: 'Horaire',
                  value: timeRange),
              const SizedBox(height: 10),
              _DetailRow(
                icon: appointment.consultationType == ConsultationType.video
                    ? Icons.videocam_outlined
                    : appointment.consultationType == ConsultationType.audio
                        ? Icons.call_outlined
                        : appointment.consultationType ==
                                ConsultationType.chat
                            ? Icons.chat_outlined
                            : Icons.meeting_room_outlined,
                label: 'Type de consultation',
                value: appointment.consultationType.label,
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.info_outline,
                label: 'Statut',
                value: appointment.status.label,
              ),
              // Recommandations post-séance : uniquement disponibles après une séance terminée.
              if (appointment.status == AppointmentStatus.completed) ...[
                const SizedBox(height: 20),
                const _SectionLabel('Recommandations post-séance'),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final patName = patient != null
                        ? (patient?.anonymousMode == true
                            ? 'Patient'
                            : '${patient!.firstName} ${patient!.lastName}'.trim())
                        : 'Patient';
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SessionRecommendationsScreen(
                        appointmentId: appointment.id,
                        patientName: patName.isEmpty ? null : patName,
                      ),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.assignment_outlined,
                            color: AppColors.tealDark, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gérer les recommandations',
                            style: TextStyle(
                                color: AppColors.tealDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.tealDark),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const _SectionLabel('Paiement'),
              const SizedBox(height: 8),
              if (_loadingPayment)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                      child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (_payment == null)
                const Text('Aucun paiement enregistré pour ce rendez-vous.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13))
              else ...[
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Montant payé',
                  value: _formatXof(_payment!.amount),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Moyen de paiement',
                  value: _payment!.method?.label ?? '—',
                ),
              ],
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.tealDark)),
            ],
          ),
        ),
      ],
    );
  }
}
