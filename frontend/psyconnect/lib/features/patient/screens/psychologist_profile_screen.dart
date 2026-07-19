import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../services/appointment_service.dart';
import '../services/psychologist_service.dart';
import 'report_psychologist_screen.dart';

// Écran de profil et de réservation d'un psychologue.
// Les créneaux sont calculés depuis les disponibilités réelles (PsyAvailabilitySlot).
// Si le psychologue n'a pas configuré ses disponibilités, une plage générique est utilisée.
class PsychologistProfileScreen extends StatefulWidget {
  const PsychologistProfileScreen({super.key, required this.psychologistId});

  final int psychologistId;

  @override
  State<PsychologistProfileScreen> createState() =>
      _PsychologistProfileScreenState();
}

class _PsychologistProfileScreenState
    extends State<PsychologistProfileScreen> {
  final _psychologistService = PsychologistService();
  final _appointmentService = AppointmentService();

  // Plage de repli : 8h-22h avec granularité de 30 min à partir de 18h.
  // Format : [heure, minute].
  static const _fallbackSlots = [
    [8,0],[9,0],[10,0],[11,0],[12,0],[13,0],[14,0],[15,0],[16,0],[17,0],
    [18,0],[18,30],
    [19,0],[19,30],
    [20,0],[20,15],[20,30],[20,45],
    [21,0],[21,15],[21,30],[21,45],
    [22,0],
  ];

  bool _loading = true;
  String? _error;
  PsychologistProfile? _psychologist;

  // Disponibilités hebdomadaires réelles du psychologue.
  List<PsyAvailabilitySlot> _availabilities = [];
  // Créneaux disponibles pour la date sélectionnée.
  List<TimeOfDay> _availableSlots = [];
  // Durée d'un créneau en minutes (déduite des disponibilités, 60 par défaut).
  int _slotDurationMinutes = 60;

  // Avis publics et anonymes : chargement indépendant de _load() pour ne pas
  // bloquer l'affichage du profil si ce second appel échoue.
  List<PsychologistReview> _reviews = [];
  bool _reviewsLoading = true;

  late DateTime _selectedDate;
  // Créneau sélectionné (null si aucun créneau n'est encore disponible).
  TimeOfDay? _selectedSlot;
  ConsultationType _selectedType = ConsultationType.video;

  bool _booking = false;
  String? _bookingError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _load();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews =
          await _psychologistService.getReviews(widget.psychologistId);
      if (!mounted) return;
      setState(() => _reviews = reviews);
    } catch (_) {
      // Échec silencieux : la section avis reste vide sans bloquer l'écran.
    } finally {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Chargement du profil et des disponibilités en parallèle.
      final results = await Future.wait([
        _psychologistService.getPsychologistById(widget.psychologistId),
        _psychologistService
            .getAvailabilities(widget.psychologistId)
            .catchError((_) => <PsyAvailabilitySlot>[]), // best-effort
      ]);

      final p = results[0] as PsychologistProfile;
      final avails = results[1] as List<PsyAvailabilitySlot>;

      setState(() {
        _psychologist = p;
        _availabilities = avails;
      });
      _updateSlotsForDate(_selectedDate);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // Recalcule les créneaux disponibles pour la date sélectionnée,
  // en filtrant les disponibilités par jour de la semaine.
  void _updateSlotsForDate(DateTime date) {
    final weekday = date.weekday; // 1=Lundi...7=Dim
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    List<TimeOfDay> rawSlots;
    int duration = 60;

    // Plage de disponibilité du psychologue pour le jour sélectionné.
    final matching =
        _availabilities.where((a) => a.dayOfWeek == weekday).toList();

    if (matching.isEmpty) {
      if (_availabilities.isEmpty) {
        // Aucune disponibilité configurée : repli sur la plage étendue par défaut.
        rawSlots = _fallbackSlots
            .map((p) => TimeOfDay(hour: p[0], minute: p[1]))
            .toList();
      } else {
        // psy a configure ses dispos mais pas pour ce jour
        setState(() {
          _availableSlots = [];
          _slotDurationMinutes = 60;
          _selectedSlot = null;
        });
        return;
      }
    } else {
      // Fusion des plages (ex : matin + après-midi).
      rawSlots = <TimeOfDay>[];
      for (final a in matching) {
        rawSlots.addAll(a.slots);
        duration = a.slotDurationMinutes;
      }
    }

    // Si c'est aujourd'hui, on supprime les créneaux déjà passés.
    if (isToday) {
      rawSlots = rawSlots
          .where((s) =>
              s.hour > now.hour ||
              (s.hour == now.hour && s.minute > now.minute))
          .toList();
    }

    setState(() {
      _availableSlots = rawSlots;
      _slotDurationMinutes = duration;
      if (_selectedSlot == null || !rawSlots.contains(_selectedSlot)) {
        _selectedSlot = rawSlots.isNotEmpty ? rawSlots.first : null;
      }
    });
  }

  Future<void> _confirmBooking() async {
    final session = context.read<AuthProvider>().session;
    final patientId = session?.profileId;

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
    final endTime =
        startTime.add(Duration(minutes: _slotDurationMinutes));

    setState(() {
      _booking = true;
      _bookingError = null;
    });
    try {
      await _appointmentService.createAppointment(
        CreateAppointmentRequest(
          patientId: patientId,
          psychologistId: widget.psychologistId,
          startTime: startTime,
          endTime: endTime,
          consultationType: _selectedType,
        ),
      );
      if (!mounted) return;

      // Le RDV reste en attente : le paiement n'intervient qu'après confirmation par le psychologue.
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Demande envoyée'),
          content: Text(
            'Votre demande de rendez-vous avec ${_psychologist!.fullName} le '
            '${_formatDate(startTime)} à ${_formatTimeOfDay(_selectedSlot!)} a été '
            'envoyée. Elle est en attente de confirmation par le '
            'psychologue : vous serez notifié dès sa réponse, et pourrez '
            'alors procéder au paiement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Signaler ce psychologue',
            onPressed: _psychologist == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReportPsychologistScreen(
                          psychologistId: widget.psychologistId,
                          psychologistName: _psychologist!.fullName,
                        ),
                      ),
                    ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _psychologist == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Psychologue introuvable.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final p = _psychologist!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: AppColors.tealLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person,
                      color: AppColors.tealDark, size: 48),
                ),
                const SizedBox(height: 12),
                Text(p.fullName, style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 2),
                Text(
                  [p.specialty, if (p.languages != null) p.languages]
                      .join(' · '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _Stat(
                  value: p.rating != null && p.rating! > 0
                      ? p.rating!.toStringAsFixed(1)
                      : '—',
                  label: 'Note'),
              _Stat(
                  value: '${p.totalReviews ?? 0}',
                  label: 'Avis'),
              _Stat(
                  value: p.yearsOfExperience != null
                      ? '${p.yearsOfExperience} ans'
                      : '—',
                  label: 'Expérience'),
              _Stat(
                  value: p.consultationPrice != null
                      ? '${p.consultationPrice} F'
                      : '—',
                  label: 'Séance'),
            ],
          ),
          if (p.bio != null && p.bio!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('À propos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(p.bio!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (p.address != null && p.address!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: AppColors.teal, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adresse du cabinet',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(p.address!,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!_reviewsLoading && _reviews.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Avis (${_reviews.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Avis anonymes, laissés par des patients ayant terminé une '
              'séance avec ce psychologue.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ..._reviews.map((r) => _ReviewTile(review: r)),
          ],
          const SizedBox(height: 24),
          Text('Modalité de consultation',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ConsultationType.video,
              ConsultationType.audio,
              ConsultationType.physical,
            ].map((type) {
              final selected = type == _selectedType;
              return ChoiceChip(
                label: Text(type.label),
                selected: selected,
                onSelected: (_) => setState(() => _selectedType = type),
                selectedColor: AppColors.teal,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: selected ? AppColors.teal : AppColors.tealMid),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Date', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final date = DateTime.now().add(Duration(days: i));
                final day = DateTime(date.year, date.month, date.day);
                final selected = day == _selectedDate;
                // Indication visuelle des jours sans créneau configuré.
                final hasSlotsForDay = _availabilities.isEmpty ||
                    _availabilities.any((a) => a.dayOfWeek == date.weekday);
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = day);
                    _updateSlotsForDate(day);
                  },
                  child: Container(
                    width: 56,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.teal
                          : hasSlotsForDay
                              ? AppColors.white
                              : AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppColors.teal
                            : hasSlotsForDay
                                ? AppColors.tealMid
                                : AppColors.tealMid.withOpacity(0.4),
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
                                    : hasSlotsForDay
                                        ? AppColors.muted
                                        : AppColors.muted.withOpacity(0.5))),
                        const SizedBox(height: 2),
                        Text('${day.day}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : hasSlotsForDay
                                        ? AppColors.text
                                        : AppColors.muted)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('Heure', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_availableSlots.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Aucun créneau disponible ce jour.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSlots.map((slot) {
                final selected = slot == _selectedSlot;
                return ChoiceChip(
                  label: Text(_formatTimeOfDay(slot)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedSlot = slot),
                  selectedColor: AppColors.teal,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color:
                            selected ? AppColors.teal : AppColors.tealMid),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 28),
          if (_bookingError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_bookingError!,
                  style: const TextStyle(color: AppColors.rose, fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: (_booking ||
                    !p.available ||
                    _availableSlots.isEmpty ||
                    _selectedSlot == null)
                ? null
                : _confirmBooking,
            child: _booking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(!p.available
                    ? 'Indisponible actuellement'
                    : _availableSlots.isEmpty
                        ? 'Aucun créneau ce jour'
                        : 'Confirmer'),
          ),
        ],
      ),
    );
  }

  static String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}h${t.minute.toString().padLeft(2, '0')}';

  static String _weekdayShort(int weekday) {
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return labels[weekday - 1];
  }

  static String _formatDate(DateTime date) {
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

// Tuile affichant un avis anonyme : note et commentaire uniquement,
// sans aucune donnée d'identité du patient (cf. ReviewResponse backend).
class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PsychologistReview review;

  @override
  Widget build(BuildContext context) {
    final rating = review.rating ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star : Icons.star_border,
                color: AppColors.gold,
                size: 16,
              ),
            ),
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.tealDark)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      ),
    );
  }
}
