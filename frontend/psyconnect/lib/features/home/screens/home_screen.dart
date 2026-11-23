import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../admin/screens/admin_shell.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../../patient/screens/patient_shell.dart';
import '../../psychologist/screens/psychologist_shell.dart';

// écran après connexion, envoie vers l'accueil du bon rôle :
// patient -> PatientShell, psy -> PsychologistShell, admin -> AdminShell
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final session = auth.session;

    // la version web ne sert que d'espace d'administration
    if (kIsWeb && session != null && session.role != UserRole.admin) {
      return const _WebAdminOnly();
    }

    if (session?.role == UserRole.patient) {
      return const PatientShell();
    }
    if (session?.role == UserRole.psychologist) {
      return const PsychologistShell();
    }
    if (session?.role == UserRole.admin) {
      return const AdminShell();
    }

    return const SplashScreen();
  }
}

class _WebAdminOnly extends StatelessWidget {
  const _WebAdminOnly();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Espace réservé à l\'administration',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Les patients et les psychologues utilisent '
                  'l\'application mobile PsyConnect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const SplashScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
