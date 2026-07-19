import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

// pagination faite cote client (les listes admin sont chargees en entier,
// pas de page/size cote backend) : decoupe une liste deja filtree/triee en
// pages de pageSize, pour pas afficher des centaines de cartes d'un coup
List<T> paginate<T>(List<T> items, int page, int pageSize) {
  final start = page * pageSize;
  if (start >= items.length) return [];
  return items.skip(start).take(pageSize).toList();
}

// nombre de pages pour totalItems a pageSize par page — toujours au moins 1
// page meme si la liste est vide ("Page 1 / 1"), plus simple que de gerer
// un cas vide a part
int pageCountFor(int totalItems, int pageSize) {
  if (totalItems == 0) return 1;
  return ((totalItems - 1) ~/ pageSize) + 1;
}

// barre "< page x/y >" — cachee toute seule s'il y a qu'une page
class PageControls extends StatelessWidget {
  const PageControls({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  // page actuelle, commence a 0
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
