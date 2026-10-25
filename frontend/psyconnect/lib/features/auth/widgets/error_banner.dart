import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

// bandeau d'erreur reutilise sur login/register, affiche quand
// AuthProvider.errorMessage est pas nul
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.danger,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}
