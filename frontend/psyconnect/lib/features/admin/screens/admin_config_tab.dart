import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../services/admin_service.dart';

/// Onglet "Config" — présent dans la nav de la maquette v2. Expose
/// désormais le seul réglage de plateforme qui existe côté backend : le
/// taux de commission prélevé par l'administrateur sur chaque paiement
/// réussi (GET/PUT /admin/platform-settings, appointment-service). Les
/// autres réglages (modération, paramètres généraux) restent un
/// placeholder honnête : aucun endpoint ne les expose encore.
class AdminConfigTab extends StatefulWidget {
  const AdminConfigTab({super.key});

  @override
  State<AdminConfigTab> createState() => _AdminConfigTabState();
}

class _AdminConfigTabState extends State<AdminConfigTab> {
  final _adminService = AdminService();

  bool _loadingRate = true;
  bool _savingRate = false;
  double _commissionRate = 20;
  final _rateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _loadRate() async {
    setState(() => _loadingRate = true);
    try {
      final settings = await _adminService.getPlatformSettings();
      if (!mounted) return;
      setState(() {
        _commissionRate = settings.commissionRatePercent;
        _rateController.text = _commissionRate.toStringAsFixed(0);
        _loadingRate = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRate = false);
    }
  }

  Future<void> _saveRate() async {
    final parsed = double.tryParse(_rateController.text.replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un pourcentage entre 0 et 100.')),
      );
      return;
    }
    setState(() => _savingRate = true);
    try {
      final updated = await _adminService.setCommissionRate(parsed);
      if (!mounted) return;
      setState(() {
        _commissionRate = updated.commissionRatePercent;
        _savingRate = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taux de commission mis à jour.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingRate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de mettre à jour le taux.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Config', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.tealMid),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.tealLight,
                  child: Icon(Icons.admin_panel_settings, color: AppColors.tealDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session?.pseudo ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(session?.role.label ?? '',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Commission de la plateforme',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          const Text(
            'Pourcentage prélevé sur chaque paiement réussi — le reste revient '
            'au psychologue. Visible dans le détail de l\'onglet Stats.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.tealMid),
            ),
            child: _loadingRate
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _rateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            suffixText: '%',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _savingRate ? null : _saveRate,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                        child: _savingRate
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Enregistrer'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.scaffoldOuter,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.construction_outlined, color: AppColors.muted),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "D'autres réglages (modération, paramètres généraux) ne "
                    "sont pas encore disponibles : aucun endpoint dédié "
                    "n'existe côté backend.",
                    style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.rose,
              side: const BorderSide(color: AppColors.rose),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
