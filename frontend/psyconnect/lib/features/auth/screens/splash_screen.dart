import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../models/user_role.dart';
import 'register_screen.dart';
import 'login_screen.dart';

/// Écran d'accueil / onboarding, fidèle à la maquette
/// "docs/PsyConnect Maquettes v2.html" (bloc .splash) : logo, message de
/// confiance, 3 points clés, puis choix du rôle pour s'inscrire.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              children: [
                const Spacer(),
                _Logo(),
                const SizedBox(height: 36),
                const _Feature(
                  icon: Icons.lock_outline,
                  text: 'Anonymat garanti — aucun jugement',
                ),
                const SizedBox(height: 10),
                const _Feature(
                  icon: Icons.location_on_outlined,
                  text: 'Psys à Dakar, Thiès, Saint-Louis…',
                ),
                const SizedBox(height: 10),
                const _Feature(
                  icon: Icons.credit_card_outlined,
                  text: 'Paiement Wave & Orange Money',
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.teal,
                    ),
                    onPressed: () => _goToRegister(context, UserRole.patient),
                    child: const Text('Je suis un patient'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70, width: 1.5),
                    ),
                    onPressed: () =>
                        _goToRegister(context, UserRole.psychologist),
                    child: const Text('Je suis un psychologue'),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text(
                    "J'ai déjà un compte — Se connecter",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToRegister(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreen(role: role)),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: SvgPicture.asset('assets/images/psyconnect_mark.svg'),
        ),
        const SizedBox(height: 14),
        Text(
          'PsyConnect\nSénégal',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Prenez soin de vous, en toute confiance.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
