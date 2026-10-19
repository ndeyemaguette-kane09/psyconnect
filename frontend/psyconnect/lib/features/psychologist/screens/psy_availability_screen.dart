import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
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
    '30 min', '45 min', '1 h', '1 h 30', '2 h'
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
      appBar: AppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppErrorState(message: _error!, onRetry: _load)
              : _buildForm(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Mes disponibilités',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            'Les patients réservent seulement sur ces créneaux.',
            style: TextStyle(fontSize: 15.5, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 22),
        // durée de créneau
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Durée d\'une consultation',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_durations.length, (i) {
              final dur = _durations[i];
              final selected = dur == _slotDurationMinutes;
              return Material(
                color: selected ? AppColors.teal : AppColors.sand,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => setState(() => _slotDurationMinutes = dur),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    child: Text(
                      _durationLabels[i],
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color:
                            selected ? AppColors.background : AppColors.text,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Ma semaine',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: List.generate(7, (i) {
              final day = i + 1;
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
          ),
        ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kWeekdayLabels[day],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      enabled
                          ? '$startHour h – $endHour h · $slotCount créneau'
                              '${slotCount > 1 ? 'x' : ''}'
                          : 'Fermé',
                      style: TextStyle(
                        fontSize: 14,
                        color: enabled ? AppColors.teal : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: AppColors.white,
                activeTrackColor: AppColors.teal,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('De',
                    style: TextStyle(color: AppColors.muted, fontSize: 15)),
                const SizedBox(width: 8),
                _HourDropdown(
                  value: startHour,
                  min: 0,
                  max: endHour - 1,
                  onChanged: onStartHourChanged,
                ),
                const SizedBox(width: 12),
                const Text('à',
                    style: TextStyle(color: AppColors.muted, fontSize: 15)),
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
      items.add(DropdownMenuItem(value: h, child: Text('$h h')));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value.clamp(min, max),
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          borderRadius: BorderRadius.circular(16),
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
