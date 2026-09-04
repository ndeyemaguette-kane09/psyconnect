import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../services/appointment_service.dart';
import '../services/psychologist_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.psychologist,
    required this.availabilities,
  });

  final PsychologistProfile psychologist;
  final List<PsyAvailabilitySlot> availabilities;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _Slots {
  const _Slots(this.slots, this.duration);

  final List<TimeOfDay> slots;
  final int duration;
}

class _BookingScreenState extends State<BookingScreen> {
  final _appointmentService = AppointmentService();

  // Plage de repli quand le psychologue n'a configuré aucune disponibilité :
  // 8h-22h, granularité plus fine en soirée. Format : [heure, minute].
  static const _fallbackSlots = [
    [8, 0], [9, 0], [10, 0], [11, 0], [12, 0], [13, 0], [14, 0], [15, 0],
    [16, 0], [17, 0],
    [18, 0], [18, 30],
    [19, 0], [19, 30],
    [20, 0], [20, 15], [20, 30], [20, 45],
    [21, 0], [21, 15], [21, 30], [21, 45],
    [22, 0],
  ];

  late DateTime _selectedDate;
  TimeOfDay? _selectedSlot;
  ConsultationType _selectedType = ConsultationType.video;

  List<TimeOfDay> _availableSlots = [];
  int _slotDurationMinutes = 60;

  bool _booking = false;
  String? _bookingError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _applySlotsFor(_selectedDate);
  }

  _Slots _slotsFor(DateTime date) {
    final weekday = date.weekday; // 1 = lundi … 7 = dimanche
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    final matching =
        widget.availabilities.where((a) => a.dayOfWeek == weekday).toList();

    List<TimeOfDay> rawSlots;
    int duration = 60;

    if (matching.isEmpty) {
      if (widget.availabilities.isEmpty) {
        // Aucune disponibilité configurée : plage générique.
        rawSlots = _fallbackSlots
            .map((s) => TimeOfDay(hour: s[0], minute: s[1]))
            .toList();
      } else {
        // Disponibilités configurées, mais pas pour ce jour-là.
        return const _Slots(<TimeOfDay>[], 60);
      }
    } else {
      // Fusion des plages du jour (ex. matin + après-midi).
      rawSlots = <TimeOfDay>[];
      for (final a in matching) {
        rawSlots.addAll(a.slots);
        duration = a.slotDurationMinutes;
      }
    }

    // Aujourd'hui : on retire les créneaux déjà passés.
    if (isToday) {
      rawSlots = rawSlots
          .where((s) =>
              s.hour > now.hour ||
              (s.hour == now.hour && s.minute > now.minute))
          .toList();
    }

    return _Slots(rawSlots, duration);
  }

  void _applySlotsFor(DateTime date) {
    final result = _slotsFor(date);
    _availableSlots = result.slots;
    _slotDurationMinutes = result.duration;
    if (_selectedSlot == null || !result.slots.contains(_selectedSlot)) {
      _selectedSlot = result.slots.isNotEmpty ? result.slots.first : null;
    }
  }

  void _selectDate(DateTime day) {
    setState(() {
      _selectedDate = day;
      _applySlotsFor(day);
    });
  }

  Future<void> _confirmBooking() async {
    if (_booking) return;

    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) {
      setState(() => _bookingError =
          'Profil patient introuvable. Déconnectez-vous puis reconnectez-vous '
          'avant de réserver.');
      return;
    }
    if (_selectedSlot == null) {
      setState(() =>
          _bookingError = 'Veuillez choisir un créneau avant de confirmer.');
      return;
    }

    final startTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _selectedSlot!.hour, _selectedSlot!.minute);
    final endTime = startTime.add(Duration(minutes: _slotDurationMinutes));

    setState(() {
      _booking = true;
      _bookingError = null;
    });
    try {
      await _appointmentService.createAppointment(
        CreateAppointmentRequest(
          patientId: patientId,
          psychologistId: widget.psychologist.id,
          startTime: startTime,
          endTime: endTime,
          consultationType: _selectedType,
        ),
      );
      if (!mounted) return;

      // Le rendez-vous reste en attente : le paiement n'intervient qu'une fois
      // le psychologue a confirmé.
      await showDialog<void>(
        context: context,
        builder: (_) => _BookingSentDialog(
          psychologistName: widget.psychologist.fullName,
          date: _formatDate(startTime),
          time: _formatTimeOfDay(_selectedSlot!),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _bookingError =
            e is ApiException ? e.message : 'La réservation a échoué.';
      });
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.psychologist;
    final canConfirm =
        !_booking && _availableSlots.isNotEmpty && _selectedSlot != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Réserver une séance'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  // ── Avec qui ────────────────────────────────────────────
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        AppAvatar(name: p.fullName, size: 46),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                p.specialty,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (p.consultationPrice != null)
                          Text(
                            '${p.consultationPrice} F',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── Modalité ────────────────────────────────────────────
                  const SectionHeader(
                    title: 'Modalité de consultation',
                    subtitle: 'Comment souhaitez-vous être reçu ?',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      ConsultationType.video,
                      ConsultationType.audio,
                      ConsultationType.physical,
                    ]
                        .map((type) => _SelectableChip(
                              label: type.label,
                              selected: type == _selectedType,
                              onTap: _booking
                                  ? null
                                  : () =>
                                      setState(() => _selectedType = type),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 26),

                  // ── Date ────────────────────────────────────────────────
                  const SectionHeader(title: 'Date'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 66,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 14,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final date = DateTime.now().add(Duration(days: i));
                        final day = DateTime(date.year, date.month, date.day);
                        final selected = day == _selectedDate;
                        final hasSlots = widget.availabilities.isEmpty ||
                            widget.availabilities
                                .any((a) => a.dayOfWeek == date.weekday);
                        return _DateCell(
                          day: day,
                          selected: selected,
                          dimmed: !hasSlots,
                          onTap: _booking ? null : () => _selectDate(day),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── Heure ───────────────────────────────────────────────
                  SectionHeader(
                    title: 'Heure',
                    subtitle: _availableSlots.isEmpty
                        ? null
                        : 'Séance de $_slotDurationMinutes minutes',
                  ),
                  const SizedBox(height: 12),
                  if (_availableSlots.isEmpty)
                    const AppNoticeCard(
                      icon: Icons.event_busy_outlined,
                      title: 'Aucun créneau ce jour',
                      message:
                          'Ce psychologue ne consulte pas à cette date. '
                          'Choisissez un autre jour dans le calendrier.',
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableSlots
                          .map((slot) => _SelectableChip(
                                label: _formatTimeOfDay(slot),
                                selected: slot == _selectedSlot,
                                onTap: _booking
                                    ? null
                                    : () =>
                                        setState(() => _selectedSlot = slot),
                              ))
                          .toList(),
                    ),

                  if (_bookingError != null) ...[
                    const SizedBox(height: 20),
                    AppCard(
                      color: AppColors.dangerBg,
                      shadow: const [],
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger, size: 19),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              _bookingError!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 15, color: AppColors.muted),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Votre demande est envoyée au psychologue. Le '
                          'paiement n\'intervient qu\'une fois qu\'il l\'a '
                          'confirmée.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Barre de confirmation ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Créneau choisi',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const Spacer(),
                      Text(
                        _selectedSlot == null
                            ? '—'
                            : '${_formatDate(_selectedDate)} · '
                                '${_formatTimeOfDay(_selectedSlot!)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: canConfirm ? _confirmBooking : null,
                    child: _booking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Confirmer la demande'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}h${t.minute.toString().padLeft(2, '0')}';

  static String _formatDate(DateTime date) {
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

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
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.day,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  static String _weekdayShort(int weekday) {
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return labels[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = selected
        ? Colors.white70
        : dimmed
            ? AppColors.faint
            : AppColors.muted;
    final dayColor = selected
        ? Colors.white
        : dimmed
            ? AppColors.faint
            : AppColors.text;

    return Material(
      color: selected ? AppColors.teal : AppColors.white,
      borderRadius: AppRadius.smAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 58,
          decoration: BoxDecoration(
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekdayShort(day.weekday),
                style: TextStyle(fontSize: 11, color: labelColor),
              ),
              const SizedBox(height: 3),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: dayColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingSentDialog extends StatelessWidget {
  const _BookingSentDialog({
    required this.psychologistName,
    required this.date,
    required this.time,
  });

  final String psychologistName;
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.send_rounded,
                  color: AppColors.success, size: 28),
            const SizedBox(height: 18),
            Text(
              'Demande envoyée',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Votre demande pour le $date à $time avec $psychologistName est '
              'partie. Vous serez notifié dès que le psychologue aura répondu, '
              'et vous pourrez alors procéder au paiement.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Terminé'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
