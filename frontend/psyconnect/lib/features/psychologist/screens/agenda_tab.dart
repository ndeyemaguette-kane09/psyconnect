import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../call/screens/call_screen.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/services/appointment_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/services/payment_service.dart';
import 'session_recommendations_screen.dart';

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

  AppointmentStatus? _statusFilter;

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
        _focusRelevantDay(appointments);
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

  static const _groupOrder = [
    AppointmentStatus.pending,
    AppointmentStatus.confirmed,
    AppointmentStatus.completed,
    AppointmentStatus.cancelled,
    AppointmentStatus.rejected,
  ];

  void _joinCall(Appointment a) {
    final patient = _patientsById[a.patientId];
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

  List<Widget> _buildContentSlivers() {
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
            separatorBuilder: (_, __) => const SizedBox.shrink(),
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
            separatorBuilder: (_, __) => const SizedBox.shrink(),
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
                child: Text('Agenda',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
            ),
            if (!_loading && _error == null && _appointments.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 0, 10),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 20),
                      itemCount: _groupOrder.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final status = i == 0 ? null : _groupOrder[i - 1];
                        final count = status == null
                            ? 0
                            : _appointments
                                .where((a) => a.status == status)
                                .length;
                        final label = status == null
                            ? 'Semaine'
                            : count > 0
                                ? '${status.label} ($count)'
                                : status.label;
                        return _FilterChip(
                          label: label,
                          selected: _statusFilter == status,
                          onTap: () =>
                              setState(() => _statusFilter = status),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_statusFilter == null)
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
                child: Center(child: CircularProgressIndicator()),
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
                  message:
                      'Les demandes de consultation de vos patients '
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
        Container(height: 1, color: AppColors.border),
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.faint,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: AppMotion.fast,
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.teal : Colors.transparent,
                shape: BoxShape.circle,
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

    return SectionHeader(title: '$label$suffix');
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
      color: selected ? AppColors.teal : AppColors.white,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
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
  final VoidCallback? onJoinCall;

  Color get _statusColor {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return AppColors.warning;
      case AppointmentStatus.confirmed:
        return AppColors.teal;
      case AppointmentStatus.completed:
        return AppColors.muted;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.rejected:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final time = '${start.hour.toString().padLeft(2, '0')}h'
        '${start.minute.toString().padLeft(2, '0')}';
    final date = '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')}';
    final name = patient != null
        ? '${patient!.firstName} ${patient!.lastName}'.trim()
        : 'Patient';

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _AppointmentDetailSheet(
              appointment: appointment,
              patient: patient,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 58,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            time,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontSize: 17,
                                  color: AppColors.tealDeep,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.faint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Patient' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppPill(
                            label: '${appointment.consultationType.label} · '
                                '${appointment.status.label}',
                            color: _statusColor,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 2),
                      child: Icon(Icons.chevron_right,
                          color: AppColors.faint, size: 20),
                    ),
                  ],
                ),
                if (appointment.status == AppointmentStatus.pending)
                  Padding(
                    padding: const EdgeInsets.only(left: 58, top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onReject,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.danger),
                              foregroundColor: AppColors.danger,
                              minimumSize: const Size(0, 42),
                            ),
                            child: const Text('Refuser'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: onConfirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              minimumSize: const Size(0, 42),
                            ),
                            child: const Text('Confirmer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (onJoinCall != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 58, top: 12),
                    child: SizedBox(
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
                          backgroundColor: AppColors.teal,
                          minimumSize: const Size(0, 42),
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
            border: Border(top: BorderSide(color: AppColors.borderStrong)),
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
                  color: AppColors.tealMid,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    color: AppColors.tealLight,
                    child: const Icon(Icons.person_outline,
                        color: AppColors.tealDark, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(name.isEmpty ? 'Patient' : name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                  ),
                  if (patient?.anonymousMode == true)
                    const AppPill(
                      label: 'Mode anonyme',
                      color: AppColors.muted,
                      dense: true,
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
              if (appointment.status == AppointmentStatus.completed) ...[
                const SizedBox(height: 20),
                const SectionHeader(title: 'Recommandations post-séance'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    final patName = patient != null
                        ? (patient.anonymousMode == true
                            ? 'Patient'
                            : '${patient.firstName} ${patient.lastName}'.trim())
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
              const SectionHeader(title: 'Paiement'),
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
