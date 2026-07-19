import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'admin_config_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_stats_tab.dart';
import 'admin_users_tab.dart';
import 'admin_validation_tab.dart';

// Conteneur principal admin — navigation style Lyynk :
// BottomAppBar avec 4 items (2 gauche, 2 droite) + FAB central (Validation)
//
// Layout : Dashboard · Utilisateurs   [FAB Validation]   Stats · Paramètres
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

const _fabTabIndex = 2; // Validation

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _goToValidation() => _selectTab(_fabTabIndex);
  void _selectTab(int i) => setState(() => _index = i);

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

      // ── FAB central : Validation ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectTab(_fabTabIndex),
        backgroundColor:
            _index == _fabTabIndex ? AppColors.tealDark : AppColors.teal,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Validation',
        child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── BottomAppBar : Dashboard · Utilisateurs   [FAB]   Stats · Paramètres
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.white,
        elevation: 8,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                index: 0,
                selectedIndex: _index,
                icon: Icons.space_dashboard_outlined,
                selectedIcon: Icons.space_dashboard,
                label: 'Dashboard',
                onTap: () => _selectTab(0),
              ),
              _NavItem(
                index: 1,
                selectedIndex: _index,
                icon: Icons.people_outline,
                selectedIcon: Icons.people,
                label: 'Utilisateurs',
                onTap: () => _selectTab(1),
              ),
              const Spacer(), // espace pour le FAB
              _NavItem(
                index: 3,
                selectedIndex: _index,
                icon: Icons.bar_chart_outlined,
                selectedIcon: Icons.bar_chart,
                label: 'Stats',
                onTap: () => _selectTab(3),
              ),
              _NavItem(
                index: 4,
                selectedIndex: _index,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Paramètres',
                onTap: () => _selectTab(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget item de navigation ────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final color = selected ? AppColors.teal : AppColors.muted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.tealLight,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge', style: const TextStyle(fontSize: 10)),
              backgroundColor: AppColors.rose,
              child: Icon(
                selected ? selectedIcon : icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
