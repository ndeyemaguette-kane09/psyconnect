import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/psychologist_models.dart';

String formatPrice(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String? _firstSentence(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final end = trimmed.indexOf(RegExp(r'[.!?](\s|$)'));
  return end == -1 ? trimmed : trimmed.substring(0, end + 1);
}

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
    final details = [
      psychologist.specialty,
      if (psychologist.city != null && psychologist.city!.trim().isNotEmpty)
        psychologist.city!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            AppAvatar(name: psychologist.fullName, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    psychologist.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                  _RatingRow(
                    rating: psychologist.rating,
                    totalReviews: psychologist.totalReviews,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 22),
          ],
        ),
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
    final price = psychologist.consultationPrice;
    final quote = _firstSentence(psychologist.bio);
    final details = [
      psychologist.specialty,
      if (psychologist.city != null && psychologist.city!.trim().isNotEmpty)
        psychologist.city!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(name: psychologist.fullName, size: 64),
            const SizedBox(width: 12),
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
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        price == null ? 'Tarif à venir' : '${formatPrice(price)} F',
                        style: TextStyle(
                          fontSize: price == null ? 13 : 15,
                          fontWeight:
                              price == null ? FontWeight.w600 : FontWeight.w700,
                          color: price == null ? AppColors.muted : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                  if (quote != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      quote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                  _RatingRow(
                    rating: psychologist.rating,
                    totalReviews: psychologist.totalReviews,
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
          const SizedBox(width: 3),
          Text(
            rating!.toStringAsFixed(1).replaceAll('.', ','),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (totalReviews != null && totalReviews! > 0)
            Text(
              ' · $totalReviews avis',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
