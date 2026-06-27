import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../services/appointment_service.dart';
import '../services/psychologist_service.dart';

/// Écran "Profil Psychologue & Réservation" (cf. maquette v2).
///
/// Le backend ne modélise aucune notion de créneaux/disponibilités (pas
/// d'endpoint pour ça) : contrairement à la maquette qui affiche des
/// créneaux fixes "disponible/complet", on laisse ici le patient choisir
/// librement une date et une heure parmi quelques créneaux usuels. La durée
/// de consultation est fixée à 1h (le backend ne l'expose pas non plus).
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

  static const _slotHours = [9, 10, 11, 14, 15, 16];
  static const _consultationDuration = Duration(hours: 1);

  bool _loading = true;
  String? _error;
  PsychologistProfile? _psychologist;

  late DateTime _selectedDate;
  int _selectedHour = 11;
  ConsultationType _selectedType = ConsultationType.video;

  bool _booking = false;
  String? _bookingError;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _psychologistService
          .getPsychologistById(widget.psychologistId);
      setState(() => _psychologist = p);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
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

    final startTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _selectedHour);
    final endTime = startTime.add(_consultationDuration);

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

      // Pas de paiement ici : le RDV est créé PENDING et reste à confirmer
      // par le psychologue. Le paiement n'intervient qu'une fois confirmé
      // (bouton "Payer" dans l'agenda du patient, cf. appointments_tab.dart) :
      // pas évoquer l'argent avant que le psychologue ait donné son accord,
      // certains psychologues n'étant pas disponibles à 100% sur
      // l'application et pouvant refuser un créneau pour un imprévu.
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Demande envoyée'),
          content: Text(
            'Votre demande de rendez-vous avec ${_psychologist!.fullName} le '
            '${_formatDate(startTime)} à ${_formatHour(_selectedHour)} a été '
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
      appBar: AppBar(title: const Text('Profil')),
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
              itemCount: 7,
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
                      borderRadius: BorderRadius.circular(14),
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
                                color:
                                    selected ? Colors.white : AppColors.text)),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _slotHours.map((hour) {
              final selected = hour == _selectedHour;
              return ChoiceChip(
                label: Text(_formatHour(hour)),
                selected: selected,
                onSelected: (_) => setState(() => _selectedHour = hour),
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
            onPressed: (_booking || !p.available) ? null : _confirmBooking,
            child: _booking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(p.available ? 'Confirmer' : 'Indisponible actuellement'),
          ),
        ],
      ),
    );
  }

  static String _formatHour(int hour) => '${hour.toString().padLeft(2, '0')}h00';

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
