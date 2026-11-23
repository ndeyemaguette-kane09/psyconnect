import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../widgets/page_controls.dart';

enum _Period { month, all }

class AdminEmergencyCallsScreen extends StatefulWidget {
  const AdminEmergencyCallsScreen({super.key});

  @override
  State<AdminEmergencyCallsScreen> createState() =>
      _AdminEmergencyCallsScreenState();
}

class _AdminEmergencyCallsScreenState extends State<AdminEmergencyCallsScreen> {
  static const _pageSize = 10;

  final _adminService = AdminService();

  bool _loading = true;
  String? _error;
  List<EmergencyCallRecord> _calls = [];
  Map<int, String> _names = {};
  _Period _period = _Period.month;
  int _page = 0;

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
      final calls = await _adminService.listEmergencyCalls();
      var names = <int, String>{};
      try {
        final psychologists = await _adminService.listPsychologists();
        names = {for (final p in psychologists) p.id: p.fullName};
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _calls = calls;
        _names = names;
        _page = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les appels d\'urgence.';
        _loading = false;
      });
    }
  }

  List<EmergencyCallRecord> get _filtered {
    if (_period == _Period.all) return _calls;
    final now = DateTime.now();
    return _calls.where((c) {
      final d = c.requestedAt;
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
  }

  String _nameOf(int? id) =>
      id == null ? 'Psychologue' : (_names[id] ?? 'Psychologue #$id');

  String _minutes(int seconds) {
    final m = (seconds / 60).ceil();
    return '$m min';
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appels d\'urgence',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 12),
                        Center(
                          child: OutlinedButton(
                              onPressed: _load, child: const Text('Réessayer')),
                        ),
                      ],
                    )
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final calls = _filtered;
    final answered = calls.where((c) => c.answered).toList();
    final totalSeconds =
        answered.fold<int>(0, (sum, c) => sum + (c.durationSeconds ?? 0));

    final byPsychologist = <int?, List<EmergencyCallRecord>>{};
    for (final c in answered) {
      byPsychologist.putIfAbsent(c.psychologistId, () => []).add(c);
    }
    final ranking = byPsychologist.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final pageCount = pageCountFor(calls.length, _pageSize);
    final pageItems = paginate(calls, _page, _pageSize);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            _periodChip('Ce mois-ci', _Period.month),
            const SizedBox(width: 8),
            _periodChip('Tout', _Period.all),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '${answered.length}',
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            height: 1.05,
            color: AppColors.text,
          ),
        ),
        Text(
          '${answered.length > 1 ? 'appels pris' : 'appel pris'} en charge'
          ' · ${_minutes(totalSeconds)} d\'écoute gratuite',
          style: const TextStyle(fontSize: 15, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          '${calls.length - answered.length} sans réponse ou annulé'
          '${calls.length - answered.length > 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 14, color: AppColors.faint),
        ),
        const SizedBox(height: 8),
        const Text(
          'L\'identité des patients n\'est jamais affichée.',
          style: TextStyle(fontSize: 13.5, color: AppColors.muted),
        ),
        if (ranking.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Par psychologue',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final entry in ranking)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _nameOf(entry.key),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${entry.value.length} appel${entry.value.length > 1 ? 's' : ''}'
                          ' · ${_minutes(entry.value.fold<int>(0, (s, c) => s + (c.durationSeconds ?? 0)))}',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Historique',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
        const SizedBox(height: 10),
        if (calls.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Aucun appel d\'urgence sur cette période.',
                  style: TextStyle(color: AppColors.muted)),
            ),
          )
        else ...[
          for (final c in pageItems) ...[
            _CallRow(
              name: _nameOf(c.psychologistId),
              dateLabel: c.requestedAt != null
                  ? _formatDateTime(c.requestedAt!)
                  : '',
              statusLabel: c.inProgress
                  ? 'En cours'
                  : c.answered
                      ? 'Pris en charge · ${_minutes(c.durationSeconds ?? 0)}'
                      : c.declined
                          ? 'Psychologue indisponible'
                          : c.cancelled
                              ? 'Annulé par le patient'
                              : 'Sans réponse',
              statusColor: c.answered
                  ? AppColors.teal
                  : c.inProgress
                      ? AppColors.gold
                      : AppColors.muted,
            ),
            const SizedBox(height: 10),
          ],
          PageControls(
            page: _page,
            pageCount: pageCount,
            onPageChanged: (p) => setState(() => _page = p),
          ),
        ],
      ],
    );
  }

  Widget _periodChip(String label, _Period value) {
    final selected = _period == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.teal,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.text,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => setState(() {
        _period = value;
        _page = 0;
      }),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.name,
    required this.dateLabel,
    required this.statusLabel,
    required this.statusColor,
  });

  final String name;
  final String dateLabel;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(dateLabel,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
