import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/psychologist_models.dart';

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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          AppAvatar(name: psychologist.fullName, size: 46),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  psychologist.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  psychologist.specialty,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _RatingRow(
                  rating: psychologist.rating,
                  totalReviews: psychologist.totalReviews,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.faint, size: 22),
        ],
      ),
    );
  }
}

class PsychologistCard extends StatelessWidget {
  const PsychologistCard({
    super.key,
    required this.psychologist,
    required this.onTap,
  });

  final PsychologistProfile psychologist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = psychologist.consultationPrice;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(name: psychologist.fullName, size: 54),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        psychologist.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$price F',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                              height: 1.2,
                            ),
                          ),
                          const Text(
                            'la séance',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.muted,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                _RatingRow(
                  rating: psychologist.rating,
                  totalReviews: psychologist.totalReviews,
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppPill(
                      label: psychologist.specialty,
                      icon: Icons.psychology_outlined,
                    ),
                    if (psychologist.city != null)
                      AppPill(
                        label: psychologist.city!,
                        icon: Icons.place_outlined,
                        color: AppColors.textSecondary,
                        background: AppColors.surfaceAlt,
                      ),
                    if (price == null)
                      const AppPill(
                        label: 'Tarif non précisé',
                        color: AppColors.muted,
                        background: AppColors.surfaceAlt,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 6, top: 16),
            child: Icon(Icons.chevron_right_rounded,
                color: AppColors.faint, size: 22),
          ),
        ],
      ),
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
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
        const SizedBox(width: 3),
        Text(
          rating!.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        if (totalReviews != null && totalReviews! > 0)
          Text(
            '  ($totalReviews avis)',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
      ],
    );
  }
}
