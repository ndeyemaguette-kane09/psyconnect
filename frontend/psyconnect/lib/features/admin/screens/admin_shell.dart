import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'admin_config_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_stats_tab.dart';
import 'admin_users_tab.dart';
import 'admin_validation_tab.dart';

/// Conteneur principal du parcours admin : bottom nav à 5 onglets, fidèle à
/// la maquette v2 ("Dashboard Administrateur", cf. docs/PsyConnect Maquettes
/// v2.html, tab #tab-admin) : Dashboard / Utilisateurs / Validation / Stats
/// / Config. Seul l'onglet Dashboard y est entièrement dessiné — les 4
/// autres sont construits à partir des endpoints /admin/** réellement
/// disponibles (cf. AdminController.java des 3 services), avec une liberté
/// de design pour les détails non couverts par la maquette.
///
/// Même architecture que PatientShell/PsychologistShell : IndexedStack pour
/// garder l'état de chaque onglet, et un callback pour permettre au
/// Dashboard de renvoyer directement vers l'onglet Validation.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _goToValidation() => setState(() => _index = 2);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdminDashboardTab(onSeeAllValidations: _goToValidation),
      const AdminUsersTab(),
      const AdminValidationTab(),
      const AdminStatsTab(),
      const AdminConfigTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.tealLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard, color: AppColors.teal),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppColors.teal),
            label: 'Utilisateurs',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check, color: AppColors.teal),
            label: 'Validation',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.teal),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.teal),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}
