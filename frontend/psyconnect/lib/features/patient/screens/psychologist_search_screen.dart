import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/loading_state.dart';
import '../models/psychologist_models.dart';
import '../services/psychologist_service.dart';
import '../widgets/psychologist_card.dart';
import 'psychologist_profile_screen.dart';

// Onglet Chercher du patient, affiché par PatientShell.
//
// Le backend ne filtre pas côté serveur (GET /psychologists ne prend aucun
// query param) : la recherche et les chips tournent côté client sur la liste
// complète. Le compteur de résultats est donc gratuit — et il rassure
// l'utilisateur sur le fait que ses filtres ont bien été pris en compte.
class PsychologistSearchScreen extends StatefulWidget {
  const PsychologistSearchScreen({super.key});

  @override
  State<PsychologistSearchScreen> createState() =>
      _PsychologistSearchScreenState();
}

class _PsychologistSearchScreenState extends State<PsychologistSearchScreen> {
  final _service = PsychologistService();
  final _searchController = TextEditingController();

  // Catégorie pour ceux qui ne savent pas quoi chercher : `specialty` est du
  // texte libre côté backend (pas un enum), impossible de filtrer par « type
  // de problème ». On affiche tout, avec un message rassurant.
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

  void _resetFilters() {
    setState(() {
      _selectedFilter = 'Tous';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final theme = Theme.of(context);
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── En-tête ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trouver un psy', style: theme.textTheme.displayMedium),
                const SizedBox(height: 3),
                Text(
                  _loading
                      ? 'Chargement des praticiens…'
                      : '${results.length} praticien${results.length > 1 ? 's' : ''} '
                          'disponible${results.length > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // ── Recherche ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Spécialité, nom, ville…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: hasQuery
                    ? IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),

          // ── Filtres ────────────────────────────────────────────────────
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final filter = _filters[i];
                final selected = filter == _selectedFilter;
                return _FilterChip(
                  label: filter,
                  selected: selected,
                  onTap: () => setState(() => _selectedFilter = filter),
                );
              },
            ),
          ),

          if (_selectedFilter == _unsureFilter) ...[
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: AppNoticeCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Pas de souci',
                message:
                    'Un premier rendez-vous avec n\'importe quel psychologue '
                    'permet de faire le point. C\'est lui qui vous orientera '
                    'ensuite vers un spécialiste si besoin.',
              ),
            ),
          ],

          const SizedBox(height: 16),
          Expanded(child: _buildBody(results)),
        ],
      ),
    );
  }

  Widget _buildBody(List<PsychologistProfile> results) {
    if (_loading) {
      return const AppListSkeleton(itemHeight: 150);
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (results.isEmpty) {
      return AppEmptyState(
        icon: Icons.person_search_outlined,
        title: 'Aucun résultat',
        message: 'Aucun psychologue ne correspond à votre recherche. '
            'Essayez un autre mot-clé ou élargissez les filtres.',
        actionLabel: 'Réinitialiser',
        onAction: _resetFilters,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.teal,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = results[i];
          return PsychologistCard(
            psychologist: p,
            onTap: () => _openProfile(p),
          );
        },
      ),
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
