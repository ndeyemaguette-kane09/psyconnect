import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Pagination 100% client (les listes admin sont déjà chargées en entier
/// via GET /admin/users, /admin/psychologists, etc. — pas de page/size côté
/// backend) : découpe une liste déjà filtrée/triée en pages de [pageSize],
/// pour éviter d'afficher des centaines de cartes d'un coup quand les
/// jeux de données de test grossissent.
List<T> paginate<T>(List<T> items, int page, int pageSize) {
  final start = page * pageSize;
  if (start >= items.length) return [];
  return items.skip(start).take(pageSize).toList();
}

/// Nombre de pages pour [totalItems] éléments à [pageSize] par page — au
/// moins 1 page même si la liste est vide, pour simplifier l'affichage
/// ("Page 1 / 1") plutôt que de gérer un cas 0/0 à part.
int pageCountFor(int totalItems, int pageSize) {
  if (totalItems == 0) return 1;
  return ((totalItems - 1) ~/ pageSize) + 1;
}

/// Barre "< Page X / Y >" — masquée automatiquement s'il n'y a qu'une page,
/// pour ne pas alourdir les écrans avec peu de données.
class PageControls extends StatelessWidget {
  const PageControls({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  /// Page courante, 0-based.
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Page précédente',
            onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            color: AppColors.tealDark,
          ),
          Text(
            'Page ${page + 1} / $pageCount',
            style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Page suivante',
            onPressed: page < pageCount - 1 ? () => onPageChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
            color: AppColors.tealDark,
          ),
        ],
      ),
    );
  }
}
