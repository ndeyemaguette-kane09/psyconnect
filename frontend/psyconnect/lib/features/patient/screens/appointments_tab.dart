import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../call/screens/call_screen.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/screens/payment_screen.dart';
import '../../payment/services/payment_service.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../services/appointment_service.dart';
import '../services/psychologist_service.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  final _appointmentService = AppointmentService();
  final _psychologistService = PsychologistService();
  final _paymentService = PaymentService();

  bool _loading = true;
  String? _error;
  List<Appointment> _appointments = [];
  Map<int, PsychologistProfile> _psychologistsById = {};

  AppointmentStatus? _statusFilter;
  bool _weekView = false;
  Set<int> _paidAppointmentIds = {};
  Set<int> _reviewedPsychologistIds = {};

  late DateTime _selectedDay;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final today = _dateKey(DateTime.now());
    _selectedDay = today;
    _weekStart = _mondayOf(today);
    _load();
  }

  static DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  bool _isActive(Appointment a) =>
      a.status != AppointmentStatus.cancelled &&
      a.status != AppointmentStatus.rejected;

  Map<DateTime, int> get _loadByDay {
    final map = <DateTime, int>{};
    for (final a in _appointments) {
      if (!_isActive(a)) continue;
      final key = _dateKey(a.startTime);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  List<Appointment> get _appointmentsOfSelectedDay => _appointments
      .where((a) => _dateKey(a.startTime) == _selectedDay)
      .toList();

  void _selectDay(DateTime day) => setState(() => _selectedDay = day);

  void _shiftWeek(int weeks) {
    setState(() {
      final offset = weeks * 7;
      _weekStart = DateTime(
          _weekStart.year, _weekStart.month, _weekStart.day + offset);
      _selectedDay = DateTime(
          _selectedDay.year, _selectedDay.month, _selectedDay.day + offset);
    });
  }

  void _goToToday() {
    final today = _dateKey(DateTime.now());
    setState(() {
      _selectedDay = today;
      _weekStart = _mondayOf(today);
    });
  }

  void _focusRelevantDay(List<Appointment> appointments) {
    final today = _dateKey(DateTime.now());
    if (appointments.any((a) => _dateKey(a.startTime) == today)) {
      _selectedDay = today;
      _weekStart = _mondayOf(today);
      return;
    }

    final upcoming = appointments
        .where((a) => _isActive(a) && a.startTime.isAfter(DateTime.now()))
        .toList();
    final target = upcoming.isNotEmpty
        ? upcoming.first.startTime
        : (appointments.isNotEmpty ? appointments.last.startTime : null);

    final day = target == null ? today : _dateKey(target);
    _selectedDay = day;
    _weekStart = _mondayOf(day);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) {
      setState(() {
        _error = 'Profil patient introuvable.';
        _loading = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        _appointmentService.getAppointmentsByPatientId(patientId),
        _psychologistService.getAllPsychologists(),
      ]);
      final appointments = results[0] as List<Appointment>;
      final psychologists = results[1] as List<PsychologistProfile>;
      appointments.sort((a, b) => a.startTime.compareTo(b.startTime));

      final confirmedIds = appointments
          .where((a) => a.status == AppointmentStatus.confirmed)
          .map((a) => a.id)
          .toList();
      final paidIds = await _loadPaidAppointmentIds(confirmedIds);

      final reviewablePsychologistIds = appointments
          .where((a) => a.status == AppointmentStatus.completed)
          .map((a) => a.psychologistId)
          .toSet();
      final reviewedIds =
          await _loadReviewedPsychologistIds(reviewablePsychologistIds);

      if (!mounted) return;
      setState(() {
        _appointments = appointments;
        _psychologistsById = {for (final p in psychologists) p.id: p};
        _paidAppointmentIds = paidIds;
        _reviewedPsychologistIds = reviewedIds;
        _focusRelevantDay(appointments);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger vos rendez-vous.';
        _loading = false;
      });
    }
  }

  Future<Set<int>> _loadPaidAppointmentIds(
      List<int> confirmedAppointmentIds) async {
    if (confirmedAppointmentIds.isEmpty) return {};
    final paid = <int>{};
    await Future.wait(confirmedAppointmentIds.map((id) async {
      try {
        final payments = await _paymentService.getPaymentsByAppointmentId(id);
        if (payments.any((p) => p.status == PaymentStatus.completed)) {
          paid.add(id);
        }
      } catch (_) {}
    }));
    return paid;
  }

  Future<Set<int>> _loadReviewedPsychologistIds(
      Set<int> psychologistIds) async {
    if (psychologistIds.isEmpty) return {};
    final reviewed = <int>{};
    await Future.wait(psychologistIds.map((id) async {
      try {
        final review = await _psychologistService.getMyReview(id);
        if (review.rating != null) {
          reviewed.add(id);
        }
      } catch (_) {}
    }));
    return reviewed;
  }

  Future<void> _pay(
      Appointment appointment, PsychologistProfile? psychologist) async {
    final price = psychologist?.consultationPrice;
    if (price == null || price <= 0) return;
    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          appointmentId: appointment.id,
          amount: price,
          otherDisplayName: psychologist?.fullName ?? 'votre psychologue',
          patientId: patientId,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _leaveReview(
      Appointment appointment, PsychologistProfile? psychologist) async {
    PsychologistReview? existing;
    try {
      existing =
          await _psychologistService.getMyReview(appointment.psychologistId);
    } catch (_) {}
    if (!mounted) return;

    final result = await showModalBottomSheet<_ReviewInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        psychologistName: psychologist?.fullName ?? 'ce psychologue',
        initialRating: existing?.rating,
        initialComment: existing?.comment,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await _psychologistService.submitReview(
        appointment.psychologistId,
        rating: result.rating,
        comment: result.comment,
      );
      if (!mounted) return;
      setState(() {
        _reviewedPsychologistIds = {
          ..._reviewedPsychologistIds,
          appointment.psychologistId,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci, votre avis a été enregistré.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message =
          e is ApiException ? e.message : "L'envoi de l'avis a échoué.";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _joinCall(Appointment appointment, PsychologistProfile? psychologist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          appointmentId: appointment.id,
          peerName: psychologist?.fullName ?? 'Psychologue',
          isVideo: appointment.consultationType == ConsultationType.video,
        ),
      ),
    );
  }

  Future<void> _reschedule(Appointment appointment) async {
    final newRange = await showModalBottomSheet<_NewSlot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RescheduleSheet(appointment: appointment),
    );
    if (newRange == null || !mounted) return;

    try {
      await _appointmentService.rescheduleAppointment(
        appointment.id,
        RescheduleAppointmentRequest(
          newStartTime: newRange.start,
          newEndTime: newRange.end,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Rendez-vous reporté'),
          content: Text(
            appointment.status == AppointmentStatus.confirmed
                ? 'Le nouveau créneau a été envoyé au psychologue, qui doit '
                    'le reconfirmer.'
                : 'Le nouveau créneau a bien été enregistré.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Le report a échoué.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _cancel(Appointment appointment) async {
    final hoursUntilStart =
        appointment.startTime.difference(DateTime.now()).inHours;
    final eligibleForRefund = hoursUntilStart >= 48;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: Text(
          eligibleForRefund
              ? "Vous annulez à plus de 48h du rendez-vous : si un paiement "
                  "a été effectué, il sera automatiquement remboursé."
              : "Vous annulez à moins de 48h du rendez-vous : aucun "
                  "remboursement ne sera appliqué, même si un paiement a "
                  "été effectué.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _appointmentService.updateAppointmentStatus(
        appointment.id,
        AppointmentStatus.cancelled,
      );
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : "L'annulation a échoué.";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _delete(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce rendez-vous ?'),
        content: const Text(
          'Cette action est définitive et ne supprime que cet élément de '
          'votre agenda — elle ne touche à aucun paiement déjà effectué.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _appointmentService.deleteAppointment(appointment.id);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      final message =
          e is ApiException ? e.message : 'La suppression a échoué.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  static const _groupOrder = [
    AppointmentStatus.pending,
    AppointmentStatus.confirmed,
    AppointmentStatus.completed,
    AppointmentStatus.cancelled,
    AppointmentStatus.rejected,
  ];

  void _openDetail(
      Appointment appointment, PsychologistProfile? psychologist) {
    final modifiable = (appointment.status == AppointmentStatus.pending ||
            appointment.status == AppointmentStatus.confirmed) &&
        appointment.startTime.isAfter(DateTime.now());
    final deletable = appointment.status == AppointmentStatus.cancelled ||
        appointment.status == AppointmentStatus.rejected;
    final canPay = appointment.status == AppointmentStatus.confirmed &&
        (psychologist?.consultationPrice ?? 0) > 0 &&
        !_paidAppointmentIds.contains(appointment.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppointmentDetailSheet(
        appointment: appointment,
        psychologist: psychologist,
        onPay: canPay ? () => _pay(appointment, psychologist) : null,
        onReschedule: modifiable ? () => _reschedule(appointment) : null,
        onCancel: modifiable ? () => _cancel(appointment) : null,
        onDelete: deletable ? () => _delete(appointment) : null,
        onReview: appointment.status == AppointmentStatus.completed
            ? () => _leaveReview(appointment, psychologist)
            : null,
        hasReview:
            _reviewedPsychologistIds.contains(appointment.psychologistId),
      ),
    );
  }

  VoidCallback? _joinActionFor(
      Appointment appointment, PsychologistProfile? psychologist) {
    final now = DateTime.now();
    final callWindowOpen = now.isAfter(
            appointment.startTime.subtract(const Duration(minutes: 10))) &&
        now.isBefore(appointment.endTime.add(const Duration(minutes: 30)));
    final isCallType = appointment.consultationType == ConsultationType.video ||
        appointment.consultationType == ConsultationType.audio;
    if (appointment.status == AppointmentStatus.confirmed &&
        isCallType &&
        callWindowOpen) {
      return () => _joinCall(appointment, psychologist);
    }
    return null;
  }

  List<Widget> _buildUpcomingSlivers() {
    final now = DateTime.now();
    final upcoming = _appointments
        .where((a) =>
            (a.status == AppointmentStatus.pending ||
                a.status == AppointmentStatus.confirmed) &&
            a.endTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final pastCount = _appointments
        .where((a) => a.status == AppointmentStatus.completed)
        .length;
    void showPast() =>
        setState(() => _statusFilter = AppointmentStatus.completed);

    if (upcoming.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Aucune séance à venir',
            message: 'Vos prochaines séances apparaîtront ici.',
            actionLabel: pastCount > 0 ? 'Voir les séances passées' : null,
            onAction: pastCount > 0 ? showPast : null,
          ),
        ),
      ];
    }

    final next = upcoming.first;
    final nextPsychologist = _psychologistsById[next.psychologistId];
    final rest = upcoming.skip(1).toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        sliver: SliverToBoxAdapter(
          child: _NextSessionPanel(
            appointment: next,
            psychologist: nextPsychologist,
            onDetail: () => _openDetail(next, nextPsychologist),
            onJoinCall: _joinActionFor(next, nextPsychologist),
          ),
        ),
      ),
      if (rest.isNotEmpty) ...[
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 26, 20, 10),
          sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Ensuite')),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: rest.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildCard(rest[i]),
          ),
        ),
      ],
      if (pastCount > 0)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 14, 20, 32),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: showPast,
                child: Text('Voir les séances passées ($pastCount)'),
              ),
            ),
          ),
        )
      else
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  Widget _buildCard(Appointment appointment) {
    final psychologist = _psychologistsById[appointment.psychologistId];
    final now = DateTime.now();
    final callWindowOpen = now.isAfter(
            appointment.startTime.subtract(const Duration(minutes: 10))) &&
        now.isBefore(appointment.endTime.add(const Duration(minutes: 30)));
    final isCallType = appointment.consultationType == ConsultationType.video ||
        appointment.consultationType == ConsultationType.audio;
    final canJoinCall = appointment.status == AppointmentStatus.confirmed &&
        isCallType &&
        callWindowOpen;
    final callNotYetOpen = appointment.status == AppointmentStatus.confirmed &&
        isCallType &&
        !callWindowOpen &&
        now.isBefore(appointment.startTime);

    return _AppointmentCard(
      appointment: appointment,
      psychologist: psychologist,
      onTap: () => _openDetail(appointment, psychologist),
      onJoinCall:
          canJoinCall ? () => _joinCall(appointment, psychologist) : null,
      callNotYetOpen: callNotYetOpen,
    );
  }

  List<Widget> _buildContentSlivers() {
    if (_statusFilter == null && !_weekView) {
      return _buildUpcomingSlivers();
    }
    if (_statusFilter != null) {
      final filtered =
          _appointments.where((a) => a.status == _statusFilter).toList();
      if (filtered.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Aucun rendez-vous',
              message: 'Rien dans « ${_statusFilter!.label} » pour l\'instant.',
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

    final items = _appointmentsOfSelectedDay;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        sliver: SliverToBoxAdapter(
          child: _DayHeading(day: _selectedDay, count: items.length),
        ),
      ),
      if (items.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 34),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: AppRadius.mdAll,
              ),
              child: const Text(
                'Journée libre',
                style: TextStyle(color: AppColors.muted, fontSize: 13.5),
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildCard(items[i]),
          ),
        ),
    ];
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
                child: Text('Mes séances',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
            ),
            if (!_loading && _error == null && _appointments.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 0, 10),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 20),
                      itemCount: _groupOrder.length + 2,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _FilterChip(
                            label: 'À venir',
                            selected: _statusFilter == null && !_weekView,
                            onTap: () => setState(() {
                              _statusFilter = null;
                              _weekView = false;
                            }),
                          );
                        }
                        if (i == 1) {
                          return _FilterChip(
                            label: 'Semaine',
                            selected: _weekView,
                            onTap: () => setState(() {
                              _statusFilter = null;
                              _weekView = true;
                            }),
                          );
                        }
                        final status = _groupOrder[i - 2];
                        final count = _appointments
                            .where((a) => a.status == status)
                            .length;
                        final label = count > 0
                            ? '${status.label} ($count)'
                            : status.label;
                        return _FilterChip(
                          label: label,
                          selected: _statusFilter == status,
                          onTap: () => setState(() {
                            _statusFilter = status;
                            _weekView = false;
                          }),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_weekView)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: _WeekStrip(
                      weekStart: _weekStart,
                      selectedDay: _selectedDay,
                      today: _dateKey(DateTime.now()),
                      loadByDay: _loadByDay,
                      onSelectDay: _selectDay,
                      onPreviousWeek: () => _shiftWeek(-1),
                      onNextWeek: () => _shiftWeek(1),
                      onToday: _goToToday,
                    ),
                  ),
                ),
            ],
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppLoadingState(label: 'Chargement de vos rendez-vous…'),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppErrorState(message: _error!, onRetry: _load),
              )
            else if (_appointments.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Aucun rendez-vous',
                  message: 'Vos rendez-vous avec vos psychologues '
                      'apparaîtront ici.',
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

const _kWeekdayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

const _kMonthShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

const _kWeekdayNames = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

const _kMonthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selectedDay,
    required this.today,
    required this.loadByDay,
    required this.onSelectDay,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onToday,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final DateTime today;
  final Map<DateTime, int> loadByDay;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onToday;

  List<DateTime> get _days => List.generate(
        7,
        (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
      );

  String get _rangeLabel {
    final days = _days;
    final start = days.first;
    final end = days.last;
    if (start.month == end.month) {
      return '${start.day} – ${end.day} ${_kMonthNames[end.month - 1]} '
          '${end.year}';
    }
    return '${start.day} ${_kMonthNames[start.month - 1]} – '
        '${end.day} ${_kMonthNames[end.month - 1]} ${end.year}';
  }

  bool get _isCurrentWeek => _days.any((d) => d == today);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onPreviousWeek,
              icon: const Icon(Icons.chevron_left, size: 22),
              color: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
              tooltip: 'Semaine précédente',
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _rangeLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  if (!_isCurrentWeek) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: onToday,
                      borderRadius: AppRadius.smAll,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        child: Text(
                          'Aujourd\'hui',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onNextWeek,
              icon: const Icon(Icons.chevron_right, size: 22),
              color: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
              tooltip: 'Semaine suivante',
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            for (final day in _days)
              Expanded(
                child: _DayCell(
                  day: day,
                  selected: day == selectedDay,
                  isToday: day == today,
                  load: loadByDay[day] ?? 0,
                  onTap: () => onSelectDay(day),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.load,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final int load;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final numberColor = selected
        ? Colors.white
        : isToday
            ? AppColors.teal
            : AppColors.text;
    final dotCount = load > 3 ? 3 : load;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _kWeekdayLetters[day.weekday - 1],
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: AppMotion.fast,
              width: 36,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.teal : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                  bottom: Radius.circular(6),
                ),
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      selected || isToday ? FontWeight.w700 : FontWeight.w600,
                  color: numberColor,
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < dotCount; i++)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: const BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle,
                      ),
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

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final weekday = _kWeekdayNames[day.weekday - 1];
    final label = '${weekday[0].toUpperCase()}${weekday.substring(1)} '
        '${day.day} ${_kMonthNames[day.month - 1]}';
    final suffix = count == 0 ? '' : ' · $count rendez-vous';

    return Text(
      '$label$suffix',
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal : AppColors.sand,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.text,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

Color _statusSolid(AppointmentStatus status) {
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

Color _statusSoft(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.pending:
      return AppColors.goldLight;
    case AppointmentStatus.confirmed:
      return AppColors.tealLight;
    case AppointmentStatus.completed:
      return AppColors.surfaceAlt;
    case AppointmentStatus.cancelled:
    case AppointmentStatus.rejected:
      return AppColors.dangerBg;
  }
}

String _hourLabel(DateTime d) => d.minute == 0
    ? '${d.hour} h'
    : '${d.hour} h ${d.minute.toString().padLeft(2, '0')}';

String _capitalize(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusSolid(status),
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
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    this.psychologist,
    required this.onTap,
    this.onJoinCall,
    this.callNotYetOpen = false,
  });

  final Appointment appointment;
  final PsychologistProfile? psychologist;
  final VoidCallback onTap;
  final VoidCallback? onJoinCall;
  final bool callNotYetOpen;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final soft = _statusSoft(appointment.status);
    final ink = appointment.status == AppointmentStatus.confirmed
        ? AppColors.teal
        : _statusSolid(appointment.status);
    final when = '${_capitalize(_kWeekdayNames[start.weekday - 1])} '
        '${_hourLabel(start)} · ${appointment.consultationType.label}';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 58,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                    bottom: Radius.circular(8),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${start.day}',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: ink,
                        height: 1,
                      ),
                    ),
                    Text(
                      _kMonthShort[start.month - 1],
                      style: TextStyle(fontSize: 12, color: ink),
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
                      psychologist?.fullName ?? 'Psychologue',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusLabel(status: appointment.status),
            ],
          ),
          if (appointment.status == AppointmentStatus.pending) ...[
            const SizedBox(height: 10),
            const Text(
              'En attente de confirmation du psychologue. Vous pourrez '
              'payer une fois le rendez-vous confirmé.',
              style: TextStyle(color: AppColors.muted, fontSize: 13.5),
            ),
          ],
          if (callNotYetOpen) ...[
            const SizedBox(height: 10),
            Text(
              "L'appel pourra être rejoint à partir de "
              '${_hourLabel(appointment.startTime.subtract(const Duration(minutes: 10)))}.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13.5),
            ),
          ],
          if (onJoinCall != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onJoinCall,
              icon: Icon(
                appointment.consultationType == ConsultationType.video
                    ? Icons.videocam
                    : Icons.call,
                size: 18,
              ),
              label: const Text('Rejoindre la séance'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextSessionPanel extends StatelessWidget {
  const _NextSessionPanel({
    required this.appointment,
    this.psychologist,
    required this.onDetail,
    this.onJoinCall,
  });

  final Appointment appointment;
  final PsychologistProfile? psychologist;
  final VoidCallback onDetail;
  final VoidCallback? onJoinCall;

  static const _soft = Color(0xFFC9DCD2);
  static const _light = Color(0xFFE3EDE7);

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final end = appointment.endTime;
    final now = DateTime.now();
    final days = DateTime(start.year, start.month, start.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final relative = days <= 0
        ? "Aujourd'hui"
        : days == 1
            ? 'Demain'
            : 'Dans $days jours';
    final name = psychologist?.fullName ?? 'votre psychologue';

    return AppPanel(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relative,
                      style: const TextStyle(color: _soft, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_capitalize(_kWeekdayNames[start.weekday - 1])} '
                      '${start.day} ${_kMonthNames[start.month - 1]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_hourLabel(start)} – ${_hourLabel(end)}',
                      style: const TextStyle(color: _light, fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppAvatar(name: name, size: 58),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Avec $name · ${appointment.consultationType.label}',
            style: const TextStyle(color: _light, fontSize: 15.5),
          ),
          const SizedBox(height: 4),
          Text(
            appointment.status == AppointmentStatus.pending
                ? 'En attente de confirmation du psychologue'
                : appointment.status.label,
            style: const TextStyle(
              color: _soft,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              if (onJoinCall != null)
                _PanelButton(
                  label: 'Rejoindre la séance',
                  filled: true,
                  onTap: onJoinCall!,
                ),
              _PanelButton(
                label: 'Voir le détail',
                filled: onJoinCall == null,
                onTap: onDetail,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.background : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? AppColors.teal : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentDetailSheet extends StatefulWidget {
  const _AppointmentDetailSheet({
    required this.appointment,
    this.psychologist,
    this.onPay,
    this.onReschedule,
    this.onCancel,
    this.onDelete,
    this.onReview,
    this.hasReview = false,
  });

  final Appointment appointment;
  final PsychologistProfile? psychologist;
  final VoidCallback? onPay;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onReview;
  final bool hasReview;

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
      final completed =
          payments.where((p) => p.status == PaymentStatus.completed).toList();
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

  void _runAndClose(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final psychologist = widget.psychologist;
    final name = psychologist?.fullName ?? 'Psychologue';
    final start = appointment.startTime;
    final end = appointment.endTime;
    final date = '${_capitalize(_kWeekdayNames[start.weekday - 1])} '
        '${start.day} ${_kMonthNames[start.month - 1]} ${start.year}';
    final timeRange = '${_hourLabel(start)} – ${_hourLabel(end)} · '
        '${appointment.consultationType.label}';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _StatusLabel(status: appointment.status),
              ),
              const SizedBox(height: 10),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeRange,
                style: const TextStyle(fontSize: 17, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    AppAvatar(name: name, size: 54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          if (psychologist != null &&
                              psychologist.specialty.isNotEmpty)
                            Text(
                              psychologist.specialty,
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
              ),
              const SizedBox(height: 22),
              if (_loadingPayment)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_payment != null)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Séance payée',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            _payment!.method?.label ?? 'Depuis votre solde',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatXof(_payment!.amount),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                )
              else if (widget.onPay != null)
                ElevatedButton(
                  onPressed: () => _runAndClose(widget.onPay!),
                  child: Text(
                    psychologist?.consultationPrice != null
                        ? 'Payer ${_formatXof(psychologist!.consultationPrice!)}'
                        : 'Payer maintenant',
                  ),
                )
              else
                const Text(
                  'Aucun paiement enregistré pour cette séance.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14.5),
                ),
              if (widget.onReview != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _runAndClose(widget.onReview!),
                  icon: Icon(
                    widget.hasReview ? Icons.star : Icons.star_outline,
                    size: 18,
                  ),
                  label: Text(widget.hasReview
                      ? 'Modifier votre avis'
                      : 'Laisser un avis'),
                ),
              ],
              if (widget.onReschedule != null ||
                  widget.onCancel != null ||
                  widget.onDelete != null) ...[
                const SizedBox(height: 18),
                if (widget.onReschedule != null)
                  _SheetLink(
                    label: 'Déplacer la séance',
                    onTap: () => _runAndClose(widget.onReschedule!),
                  ),
                if (widget.onCancel != null) ...[
                  _SheetLink(
                    label: 'Annuler la séance',
                    color: AppColors.danger,
                    onTap: () => _runAndClose(widget.onCancel!),
                  ),
                  const Text(
                    'Remboursée sur votre solde si vous annulez au moins '
                    '48 h avant.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                if (widget.onDelete != null)
                  _SheetLink(
                    label: 'Supprimer de ma liste',
                    color: AppColors.danger,
                    onTap: () => _runAndClose(widget.onDelete!),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SheetLink extends StatelessWidget {
  const _SheetLink({
    required this.label,
    required this.onTap,
    this.color = AppColors.teal,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _NewSlot {
  const _NewSlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({required this.appointment});

  final Appointment appointment;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  static const _slotHours = [9, 10, 11, 14, 15, 16];

  late DateTime _selectedDate;
  late int _selectedHour;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _selectedHour = _slotHours.first;
  }

  Duration get _duration =>
      widget.appointment.endTime.difference(widget.appointment.startTime);

  void _confirm() {
    final start = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _selectedHour);
    Navigator.of(context)
        .pop(_NewSlot(start: start, end: start.add(_duration)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.tealMid,
                ),
              ),
            ),
            Text('Reporter le rendez-vous',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text('Nouvelle date',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final date = DateTime.now().add(Duration(days: i + 1));
                  final day = DateTime(date.year, date.month, date.day);
                  final selected = day == _selectedDate;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = day),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.teal : AppColors.white,
                        border: Border.all(
                          color: selected ? AppColors.teal : AppColors.tealMid,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_weekdayShort(day.weekday),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: selected
                                      ? Colors.white70
                                      : AppColors.muted)),
                          const SizedBox(height: 2),
                          Text('${day.day}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.text)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text('Nouvelle heure',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slotHours.map((hour) {
                final selected = hour == _selectedHour;
                return ChoiceChip(
                  label: Text('${hour.toString().padLeft(2, '0')}h00'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedHour = hour),
                  selectedColor: AppColors.teal,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                        color: selected ? AppColors.teal : AppColors.tealMid),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _confirm,
              child: const Text('Confirmer le nouveau créneau'),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayShort(int weekday) {
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return labels[weekday - 1];
  }
}

class _ReviewInput {
  const _ReviewInput({required this.rating, this.comment});

  final int rating;
  final String? comment;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.psychologistName,
    this.initialRating,
    this.initialComment,
  });

  final String psychologistName;
  final int? initialRating;
  final String? initialComment;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 5;
    _commentController =
        TextEditingController(text: widget.initialComment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _confirm() {
    final comment = _commentController.text.trim();
    Navigator.of(context).pop(
      _ReviewInput(rating: _rating, comment: comment.isEmpty ? null : comment),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.tealMid,
                ),
              ),
            ),
            Text('Votre avis sur ${widget.psychologistName}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Votre avis reste anonyme, y compris pour le psychologue.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return IconButton(
                    onPressed: () => setState(() => _rating = i + 1),
                    icon: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: AppColors.gold,
                      size: 32,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Un commentaire (facultatif)',
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirm,
              child: const Text("Envoyer l'avis"),
            ),
          ],
        ),
      ),
    );
  }
}
