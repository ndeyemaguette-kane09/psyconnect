import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../call/screens/call_screen.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/services/appointment_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/services/payment_service.dart';
import '../utils/patient_name.dart';
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

  _AgendaView _view = _AgendaView.upcoming;

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

  void _joinCall(Appointment a) {
    final name = _displayName(_patientsById[a.patientId]);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallScreen(
        appointmentId: a.id,
        peerName: name,
        isVideo: a.consultationType == ConsultationType.video,
      ),
    ));
  }

  bool _canJoinCall(Appointment a) {
    final now = DateTime.now();
    final callWindowOpen =
        now.isAfter(a.startTime.subtract(const Duration(minutes: 10))) &&
        now.isBefore(a.endTime.add(const Duration(minutes: 30)));
    return a.status == AppointmentStatus.confirmed &&
        (a.consultationType == ConsultationType.video ||
            a.consultationType == ConsultationType.audio) &&
        callWindowOpen;
  }

  void _openDetail(Appointment a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppointmentDetailSheet(
        appointment: a,
        patient: _patientsById[a.patientId],
      ),
    );
  }

  List<Appointment> get _upcomingActive {
    final now = DateTime.now();
    return _appointments
        .where((a) => _isActive(a) && a.endTime.isAfter(now))
        .toList();
  }

  List<Appointment> get _pending => _appointments
      .where((a) => a.status == AppointmentStatus.pending)
      .toList();

  List<Appointment> get _completed => _appointments
      .where((a) => a.status == AppointmentStatus.completed)
      .toList()
      .reversed
      .toList();

  Widget _row(Appointment a) => _AgendaRow(
        appointment: a,
        patientName: _displayName(_patientsById[a.patientId]),
        onTap: () => _openDetail(a),
      );

  Widget _request(Appointment a) => _RequestCard(
        appointment: a,
        patientName: _displayName(_patientsById[a.patientId]),
        onConfirm: () => _updateStatus(a, AppointmentStatus.confirmed),
        onReject: () => _updateStatus(a, AppointmentStatus.rejected),
        onTap: () => _openDetail(a),
      );

  Widget _rowsGroup(List<Appointment> list) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [for (final a in list) _row(a)]),
      );

  Widget _heading(String title) => Padding(
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

  Widget _quiet(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15.5,
            height: 1.5,
            color: AppColors.muted,
          ),
        ),
      );

  List<Widget> _upcomingView() {
    final upcoming = _upcomingActive;
    final pending = upcoming
        .where((a) => a.status == AppointmentStatus.pending)
        .toList();
    final confirmed = upcoming
        .where((a) => a.status != AppointmentStatus.pending)
        .toList();
    final next = confirmed.isNotEmpty ? confirmed.first : null;
    final later = confirmed.skip(1).toList();

    if (next == null && pending.isEmpty) {
      return [
        _quiet('Aucune consultation à venir. Les demandes de vos patients '
            'apparaîtront ici.'),
      ];
    }
    return [
      if (next != null) ...[
        _NextPanel(
          appointment: next,
          patientName: _displayName(_patientsById[next.patientId]),
          onOpen: () => _openDetail(next),
          onJoinCall: _canJoinCall(next) ? () => _joinCall(next) : null,
        ),
        const SizedBox(height: 24),
      ],
      if (pending.isNotEmpty) ...[
        _heading('À confirmer'),
        for (final a in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _request(a),
          ),
        const SizedBox(height: 14),
      ],
      if (later.isNotEmpty) ...[
        _heading('Ensuite'),
        _rowsGroup(later),
      ],
    ];
  }

  List<Widget> _weekView() {
    final items = _appointmentsOfSelectedDay;
    final weekday = _kWeekdayNames[_selectedDay.weekday - 1];
    final label = '${weekday[0].toUpperCase()}${weekday.substring(1)} '
        '${_selectedDay.day} ${_kMonthNames[_selectedDay.month - 1]}';
    return [
      _WeekStrip(
        weekStart: _weekStart,
        selectedDay: _selectedDay,
        today: _dateKey(DateTime.now()),
        loadByDay: _loadByDay,
        onSelectDay: _selectDay,
        onPreviousWeek: () => _shiftWeek(-1),
        onNextWeek: () => _shiftWeek(1),
        onToday: _goToToday,
      ),
      const SizedBox(height: 20),
      _heading(label),
      if (items.isEmpty) _quiet('Journée libre.') else _rowsGroup(items),
    ];
  }

  List<Widget> _pendingView() {
    final list = _pending;
    if (list.isEmpty) return [_quiet('Aucune demande en attente.')];
    return [
      for (final a in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _request(a),
        ),
    ];
  }

  List<Widget> _completedView() {
    final list = _completed;
    if (list.isEmpty) return [_quiet('Aucune consultation terminée.')];
    return [_rowsGroup(list)];
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pending.length;
    final List<Widget> content;
    switch (_view) {
      case _AgendaView.upcoming:
        content = _upcomingView();
      case _AgendaView.week:
        content = _weekView();
      case _AgendaView.pending:
        content = _pendingView();
      case _AgendaView.completed:
        content = _completedView();
    }

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
                'Agenda',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final v in _AgendaView.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ViewChip(
                        label: v == _AgendaView.pending && pendingCount > 0
                            ? '${v.label} ($pendingCount)'
                            : v.label,
                        selected: _view == v,
                        onTap: () => setState(() => _view = v),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else
              ...content,
          ],
        ),
      ),
    );
  }
}

enum _AgendaView { upcoming, week, pending, completed }

extension on _AgendaView {
  String get label {
    switch (this) {
      case _AgendaView.upcoming:
        return 'À venir';
      case _AgendaView.week:
        return 'Semaine';
      case _AgendaView.pending:
        return 'À confirmer';
      case _AgendaView.completed:
        return 'Terminées';
    }
  }
}

String _displayName(PatientProfile? p) => patientDisplayName(p);

String _hour(DateTime d) => d.minute == 0
    ? '${d.hour} h'
    : '${d.hour} h ${d.minute.toString().padLeft(2, '0')}';

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

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

const _kWeekdayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

const _kWeekdayNames = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];

const _kMonthNames = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

const _kMonthShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

class _ViewChip extends StatelessWidget {
  const _ViewChip({
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
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.background : AppColors.text,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor(status),
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

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.pending});

  final DateTime date;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final ink = pending ? const Color(0xFF7A561A) : AppColors.teal;
    return Container(
      width: 46,
      height: 54,
      decoration: BoxDecoration(
        color: pending ? AppColors.goldLight : AppColors.tealLight,
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
            '${date.day}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1,
              color: ink,
            ),
          ),
          Text(
            _kMonthShort[date.month - 1],
            style: TextStyle(fontSize: 11, color: ink),
          ),
        ],
      ),
    );
  }
}

class _NextPanel extends StatelessWidget {
  const _NextPanel({
    required this.appointment,
    required this.patientName,
    required this.onOpen,
    required this.onJoinCall,
  });

  final Appointment appointment;
  final String patientName;
  final VoidCallback onOpen;
  final VoidCallback? onJoinCall;

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
    final isVideo = appointment.consultationType == ConsultationType.video;

    return AppPanel(
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
                      style: const TextStyle(
                        color: Color(0xFFC9DCD2),
                        fontSize: 15,
                      ),
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
                      '${_hour(start)} – ${_hour(end)}',
                      style: const TextStyle(
                        color: Color(0xFFE3EDE7),
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
              AppAvatar(name: patientName, size: 52),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Avec $patientName · '
            '${appointment.consultationType.label.toLowerCase()}',
            style: const TextStyle(color: Color(0xFFE3EDE7), fontSize: 15.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onJoinCall != null)
                FilledButton.icon(
                  onPressed: onJoinCall,
                  icon: Icon(
                    isVideo ? Icons.videocam_outlined : Icons.call_outlined,
                    size: 20,
                  ),
                  label: Text(isVideo ? 'Rejoindre la visio' : 'Appeler'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.teal,
                  ),
                ),
              TextButton(
                onPressed: onOpen,
                style: onJoinCall == null
                    ? TextButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.teal,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      )
                    : TextButton.styleFrom(
                        foregroundColor: AppColors.background,
                      ),
                child: const Text(
                  'Voir le détail',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
    required this.onTap,
  });

  final Appointment appointment;
  final String patientName;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final future = start.isAfter(DateTime.now());
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _DateTile(date: start, pending: true),
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
                          '${_capitalize(_kWeekdayNames[start.weekday - 1])}, '
                          '${_hour(start)} · '
                          '${appointment.consultationType.label.toLowerCase()}',
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
              if (future)
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
                )
              else
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Date passée sans réponse',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onReject,
                      child: const Text('Refuser'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.appointment,
    required this.patientName,
    required this.onTap,
  });

  final Appointment appointment;
  final String patientName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _DateTile(
              date: start,
              pending: appointment.status == AppointmentStatus.pending,
            ),
            const SizedBox(width: 14),
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
                    '${_capitalize(_kWeekdayNames[start.weekday - 1])}, '
                    '${_hour(start)} · '
                    '${appointment.consultationType.label.toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusLabel(status: appointment.status),
          ],
        ),
      ),
    );
  }
}

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
      return 'Du ${start.day} au ${end.day} ${_kMonthNames[end.month - 1]}';
    }
    return 'Du ${start.day} ${_kMonthNames[start.month - 1]} au '
        '${end.day} ${_kMonthNames[end.month - 1]}';
  }

  bool get _isCurrentWeek => _days.any((d) => d == today);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPreviousWeek,
                icon: const Icon(Icons.chevron_left, size: 24),
                color: AppColors.text,
                tooltip: 'Semaine précédente',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _rangeLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    if (!_isCurrentWeek)
                      GestureDetector(
                        onTap: onToday,
                        child: const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Revenir à aujourd\'hui',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onNextWeek,
                icon: const Icon(Icons.chevron_right, size: 24),
                color: AppColors.text,
                tooltip: 'Semaine suivante',
              ),
            ],
          ),
          const SizedBox(height: 4),
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
        ],
      ),
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
        ? AppColors.background
        : isToday
            ? AppColors.teal
            : AppColors.text;
    final dotCount = load > 3 ? 3 : load;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _kWeekdayLetters[day.weekday - 1],
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Container(
              width: 38,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.teal : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                  bottom: Radius.circular(8),
                ),
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      selected || isToday ? FontWeight.w800 : FontWeight.w600,
                  color: numberColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < dotCount; i++)
                    Container(
                      width: 5,
                      height: 5,
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
    return '$buffer F CFA';
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final patient = widget.patient;
    final name = _displayName(patient);
    final start = appointment.startTime;
    final end = appointment.endTime;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  AppAvatar(name: name, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: AppColors.text,
                          ),
                        ),
                        if (patient?.anonymousMode == true)
                          const Text(
                            'Le patient a choisi le mode anonyme',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _DetailRow(
                label: 'Date',
                value: '${_capitalize(_kWeekdayNames[start.weekday - 1])} '
                    '${start.day} ${_kMonthNames[start.month - 1]} '
                    '${start.year}',
              ),
              _DetailRow(
                label: 'Horaire',
                value: '${_hour(start)} – ${_hour(end)}',
              ),
              _DetailRow(
                label: 'Type',
                value: appointment.consultationType.label,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Statut',
                        style:
                            TextStyle(fontSize: 16, color: AppColors.muted),
                      ),
                    ),
                    _StatusLabel(status: appointment.status),
                  ],
                ),
              ),
              _DetailRow(
                label: 'Paiement',
                value: _loadingPayment
                    ? '…'
                    : _payment == null
                        ? 'Aucun paiement'
                        : _formatXof(_payment!.amount),
              ),
              if (_payment?.method != null)
                _DetailRow(
                  label: 'Moyen de paiement',
                  value: _payment!.method!.label,
                ),
              if (appointment.status == AppointmentStatus.completed) ...[
                const SizedBox(height: 18),
                Material(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SessionRecommendationsScreen(
                          appointmentId: appointment.id,
                          patientName: name,
                        ),
                      ));
                    },
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recommandations après la séance',
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: AppColors.muted),
                        ],
                      ),
                    ),
                  ),
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
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
