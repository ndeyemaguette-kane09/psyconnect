import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.label,
    required this.amount,
    required this.loading,
  });

  final String label;
  final String amount;
  final bool loading;

  static const Color _line = Color(0xFF3B3731);
  static const Color _soft = Color(0xFFB8B0A4);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 180,
        color: AppColors.text,
        child: Stack(
          children: [
            for (var i = 0; i < 4; i++)
              Positioned(
                right: -60.0 + i * 22,
                bottom: -40,
                child: Container(
                  width: 260.0 - i * 44,
                  height: 220.0 - i * 22,
                  decoration: BoxDecoration(
                    border: Border.all(color: _line, width: 2),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular((260.0 - i * 44) / 2),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(5),
                            bottom: Radius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PsyConnect',
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(color: _soft, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      loading
                          ? const SizedBox(
                              height: 30,
                              width: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.background,
                              ),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Flexible(
                                  child: Text(
                                    amount,
                                    style: const TextStyle(
                                      color: AppColors.background,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 44,
                                      letterSpacing: -1.2,
                                      height: 1.05,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'F CFA',
                                  style: TextStyle(
                                    color: _soft,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                    ],
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
