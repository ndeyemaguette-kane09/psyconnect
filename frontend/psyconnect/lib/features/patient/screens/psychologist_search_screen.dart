import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/psychologist_models.dart';
import '../services/psychologist_service.dart';
import '../widgets/psychologist_card.dart';
import 'psychologist_profile_screen.dart';

/// Contenu de l'onglet "Chercher" du parcours patient (cf. maquette v2,
/// "Recherche de Psychologue") — affiché par [PatientShell], pas de
/// Scaffold/AppBar propre ici. Le backend ne propose pas de filtrage côté
/// serveur (GET /psychologists ne prend aucun query param), donc la
/// recherche/les chips de filtre opèrent côté client sur la liste complète.
class PsychologistSearchScreen extends StatefulWidget {
  const PsychologistSearchScreen({super.key});

  @override
  State<PsychologistSearchScreen> createState() =>
      _PsychologistSearchScreenState();
}

class _PsychologistSearchScreenState extends State<PsychologistSearchScreen> {
  final _service = PsychologistService();
  final _searchController = TextEditingController();

  /// Catégorie pensée pour les patients qui n'ont jamais consulté et ne
  /// savent pas quelle spécialité chercher : comme `specialty` est un champ
  /// libre côté backend (pas d'enum ni de taxonomie diagnostique), on ne
  /// peut pas filtrer par "type de problème" de façon fiable. Cette
  /// catégorie affiche donc tous les psychologues (comme "Tous"), mais avec
  /// un message qui explique qu'un premier rendez-vous suffit pour faire le
  /// point, le psychologue se chargeant ensuite d'orienter si besoin.
  static const _unsureFilter = 'Je ne sais pas encore';

  static const _filters = [
    'Tous',
    _unsureFilter,
    'Anxiété',
    'Dépression',
    'Couple',
    'Enfant',
  ];
  String _selectedFilter = 'Tous';

  bool _loading = true;
  String? _error;
  List<PsychologistProfile> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getAllPsychologists();
      setState(() => _all = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<PsychologistProfile> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _all.where((p) {
      final matchesFilter = _selectedFilter == 'Tous' ||
          _selectedFilter == _unsureFilter ||
          p.specialty.toLowerCase().contains(_selectedFilter.toLowerCase());
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return p.fullName.toLowerCase().contains(query) ||
          p.specialty.toLowerCase().contains(query) ||
          (p.city?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _openProfile(PsychologistProfile p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PsychologistProfileScreen(psychologistId: p.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Trouver un psy',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Spécialité, nom, ville…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final filter = _filters[i];
                  final selected = filter == _selectedFilter;
                  return ChoiceChip(
                    label: Text(filter),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedFilter = filter),
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
                        color: selected ? AppColors.teal : AppColors.tealMid,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_selectedFilter == _unsureFilter) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: AppColors.gold, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pas de souci : un premier rendez-vous avec '
                          "n'importe quel psychologue permet de faire le "
                          "point sur ce que vous traversez. C'est lui qui "
                          'vous orientera ensuite vers un spécialiste si '
                          'besoin.',
                          style:
                              TextStyle(color: AppColors.text, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildBody(results)),
          ],
        ),
      );
  }

  Widget _buildBody(List<PsychologistProfile> results) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.muted, size: 36),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return const Center(
        child: Text('Aucun psychologue ne correspond à votre recherche.',
            style: TextStyle(color: AppColors.muted)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = results[i];
          return PsychologistCard(
            psychologist: p,
            onViewProfile: () => _openProfile(p),
            onBook: () => _openProfile(p),
          );
        },
      ),
    );
  }
}
