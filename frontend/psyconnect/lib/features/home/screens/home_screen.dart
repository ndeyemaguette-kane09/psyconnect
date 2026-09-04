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
// patient -> PatientShell (Accueil/Chercher/RDV/Messages/Profil)
// psy -> PsychologistShell (Accueil/Agenda/Patients/Messages/Stats)
// admin -> AdminShell (Dashboard/Utilisateurs/Validation/Stats/Config)
// suit la maquette v2 quand elle existe pour l'écran
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final session = auth.session;

    if (session?.role == UserRole.patient) {
      return const PatientShell();
    }
    if (session?.role == UserRole.psychologist) {
      return const PsychologistShell();
    }
    if (session?.role == UserRole.admin) {
      return const AdminShell();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                ),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bienvenue',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session?.pseudo ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connecté en tant que '
                      '${session == null ? '' : session.role.label}',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "L'authentification fonctionne : le reste de l'app "
                "(accueil patient, recherche de psy, réservation, etc.) "
                'sera construit ici, écran par écran, selon les maquettes.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
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
    );
  }
}
