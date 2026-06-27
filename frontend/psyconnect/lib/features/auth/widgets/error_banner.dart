import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Bandeau d'erreur réutilisé sur les écrans login/register, affiché quand
/// AuthProvider.errorMessage n'est pas nul.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.rose, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.rose, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
