import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

// bandeau d'erreur reutilise sur login/register, affiche quand
// AuthProvider.errorMessage est pas nul
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
