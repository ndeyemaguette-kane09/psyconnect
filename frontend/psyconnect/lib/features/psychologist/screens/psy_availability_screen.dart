import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/availability_models.dart';
import '../services/availability_service.dart';

// ecran de gestion des disponibilites hebdomadaires du psy
// le psy active/desactive chaque jour et definit ses plages horaires
// un seul slot-duration s'applique a toute la semaine (plus simple pour l'UX)
class PsyAvailabilityScreen extends StatefulWidget {
  const PsyAvailabilityScreen({super.key, required this.psychologistId});

  final int psychologistId;

  @override
  State<PsyAvailabilityScreen> createState() => _PsyAvailabilityScreenState();
}

class _PsyAvailabilityScreenState extends State<PsyAvailabilityScreen> {
  final _service = AvailabilityService();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // etat editable de chaque jour (1=Lundi...7=Dim)
  // _dayEnabled[i] : true si le psy travaille ce jour
  // _startHour[i] / _endHour[i] : plages horaires
  final _dayEnabled = List<bool>.filled(8, false); // index 1..7
  final _startHour = List<int>.filled(8, 9);       // defaut 9h
  final _endHour = List<int>.filled(8, 17);        // defaut 17h
  int _slotDurationMinutes = 60;

  static const _durations = [30, 45, 60, 90, 120];
  static const _durationLabels = [
    '30 min', '45 min', '1h', '1h30', '2h'
  ];

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
    try {
      final availabilities =
          await _service.getAvailabilities(widget.psychologistId);
      _applyAvailabilities(availabilities);
    } catch (e) {
      setState(
          () => _error = e is ApiException ? e.message : 'Chargement échoué.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyAvailabilities(List<PsychologistAvailability> list) {
    // reset
    for (int i = 1; i <= 7; i++) {
      _dayEnabled[i] = false;
      _startHour[i] = 9;
      _endHour[i] = 17;
    }
    int detectedDuration = 60;

    for (final a in list) {
      final d = a.dayOfWeek;
      if (d >= 1 && d <= 7) {
        _dayEnabled[d] = true;
        _startHour[d] = a.startHour;
        _endHour[d] = a.endHour;
        detectedDuration = a.slotDurationMinutes;
      }
    }
    setState(() => _slotDurationMinutes = detectedDuration);
  }

  Future<void> _save() async {
    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) return;

    setState(() => _saving = true);

    final requests = <AvailabilityRequest>[];
    for (int d = 1; d <= 7; d++) {
      if (_dayEnabled[d]) {
        requests.add(AvailabilityRequest(
          dayOfWeek: d,
          startHour: _startHour[d],
          endHour: _endHour[d],
          slotDurationMinutes: _slotDurationMinutes,
        ));
      }
    }

    try {
      await _service.saveAvailabilities(psychologistId, requests);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disponibilités enregistrées.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              e is ApiException ? e.message : 'Enregistrement échoué.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: const Text(
          'Mes disponibilités',
          style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 16),
        ),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8)),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer',
                        style: TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // durée de créneau
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Durée de chaque consultation',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                'S\'applique à tous les jours de la semaine.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_durations.length, (i) {
                  final dur = _durations[i];
                  final selected = dur == _slotDurationMinutes;
                  return ChoiceChip(
                    label: Text(_durationLabels[i]),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _slotDurationMinutes = dur),
                    selectedColor: AppColors.teal,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                          color: selected ? AppColors.teal : AppColors.tealMid),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Planning hebdomadaire',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        const Text(
          'Activez les jours travaillés et définissez vos horaires.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...List.generate(7, (i) {
          final day = i + 1; // 1=Lundi ... 7=Dim
          return _DayRow(
            day: day,
            enabled: _dayEnabled[day],
            startHour: _startHour[day],
            endHour: _endHour[day],
            slotDurationMinutes: _slotDurationMinutes,
            onToggle: (v) => setState(() => _dayEnabled[day] = v),
            onStartHourChanged: (h) => setState(() {
              _startHour[day] = h;
              if (_endHour[day] <= h) _endHour[day] = h + 1;
            }),
            onEndHourChanged: (h) => setState(() {
              _endHour[day] = h;
              if (_startHour[day] >= h) _startHour[day] = h - 1;
            }),
          );
        }),
      ],
    );
  }
}

// ligne d'un jour dans le planning
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.enabled,
    required this.startHour,
    required this.endHour,
    required this.slotDurationMinutes,
    required this.onToggle,
    required this.onStartHourChanged,
    required this.onEndHourChanged,
  });

  final int day;
  final bool enabled;
  final int startHour;
  final int endHour;
  final int slotDurationMinutes;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onStartHourChanged;
  final ValueChanged<int> onEndHourChanged;

  @override
  Widget build(BuildContext context) {
    final slotCount = enabled
        ? ((endHour - startHour) * 60 / slotDurationMinutes).floor()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: enabled ? AppColors.teal : AppColors.tealMid,
          width: enabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: AppColors.teal,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  kWeekdayLabels[day],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: enabled ? AppColors.text : AppColors.muted,
                  ),
                ),
              ),
              if (enabled && slotCount > 0)
                Text(
                  '$slotCount créneau${slotCount > 1 ? 'x' : ''}',
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 4),
                const Text('De',
                    style:
                        TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(width: 8),
                _HourDropdown(
                  value: startHour,
                  min: 0,
                  max: endHour - 1,
                  onChanged: onStartHourChanged,
                ),
                const SizedBox(width: 12),
                const Text('à',
                    style:
                        TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(width: 8),
                _HourDropdown(
                  value: endHour,
                  min: startHour + 1,
                  max: 24,
                  onChanged: onEndHourChanged,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// dropdown d'heures (0..24)
class _HourDropdown extends StatelessWidget {
  const _HourDropdown({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<int>>[];
    for (int h = min; h <= max; h++) {
      items.add(DropdownMenuItem(
        value: h,
        child: Text('${h.toString().padLeft(2, '0')}h00'),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.tealMid),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value.clamp(min, max),
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          style: const TextStyle(
              color: AppColors.text, fontWeight: FontWeight.w600),
          isDense: true,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
