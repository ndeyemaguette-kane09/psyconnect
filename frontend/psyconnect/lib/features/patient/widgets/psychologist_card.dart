import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/psychologist_models.dart';

/// Carte compacte utilisée pour la section "Recommandé pour vous" de
/// l'accueil patient (cf. `.psy-mini` dans la maquette v2).
class PsychologistMiniCard extends StatelessWidget {
  const PsychologistMiniCard({
    super.key,
    required this.psychologist,
    required this.onTap,
  });

  final PsychologistProfile psychologist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const _Avatar(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(psychologist.fullName,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    psychologist.specialty,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _RatingRow(
                      rating: psychologist.rating,
                      totalReviews: psychologist.totalReviews),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onTap, child: const Text('Voir')),
          ],
        ),
      ),
    );
  }
}

/// Carte complète utilisée dans la liste de recherche (cf. `.psy-card`).
class PsychologistCard extends StatelessWidget {
  const PsychologistCard({
    super.key,
    required this.psychologist,
    required this.onViewProfile,
    required this.onBook,
  });

  final PsychologistProfile psychologist;
  final VoidCallback onViewProfile;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final priceLabel = psychologist.consultationPrice != null
        ? '${psychologist.consultationPrice} F'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Avatar(size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(psychologist.fullName,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _RatingRow(
                              rating: psychologist.rating,
                              totalReviews: psychologist.totalReviews),
                          if (psychologist.city != null) ...[
                            const Text('  ·  ',
                                style: TextStyle(color: AppColors.muted)),
                            Icon(Icons.place_outlined,
                                size: 13, color: AppColors.muted),
                            Text(' ${psychologist.city}',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                          ],
                          if (priceLabel != null) ...[
                            const Text('  ·  ',
                                style: TextStyle(color: AppColors.muted)),
                            Text(priceLabel,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Chip(label: psychologist.specialty),
                          if (!psychologist.available)
                            const _Chip(
                                label: 'Indisponible',
                                color: AppColors.rose,
                                bg: AppColors.errorBg),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewProfile,
                    child: const Text('Voir profil'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: psychologist.available ? onBook : null,
                    child: const Text('Réserver'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.tealLight,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, color: AppColors.tealDark, size: size * 0.55),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({this.rating, this.totalReviews});

  final double? rating;
  final int? totalReviews;

  @override
  Widget build(BuildContext context) {
    if (rating == null || rating == 0) {
      return const Text('Nouveau', style: TextStyle(color: AppColors.muted, fontSize: 12));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, color: AppColors.gold, size: 13),
        const SizedBox(width: 2),
        Text(rating!.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        if (totalReviews != null && totalReviews! > 0)
          Text(' ($totalReviews avis)',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.color, this.bg});

  final String label;
  final Color? color;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? AppColors.tealLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.tealDark,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
