import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../services/admin_service.dart';
import 'admin_reports_tab.dart';

// onglet "Paramètres" — 3 sections :
//   1. Réglages plateforme (taux commission)
//   2. Modération (accès aux signalements)
//   3. Communication (broadcast annonce admin → utilisateurs)
class AdminConfigTab extends StatefulWidget {
  const AdminConfigTab({super.key});

  @override
  State<AdminConfigTab> createState() => _AdminConfigTabState();
}

class _AdminConfigTabState extends State<AdminConfigTab> {
  final _adminService = AdminService();

  // --- commission ---
  bool _loadingRate = true;
  bool _savingRate = false;
  double _commissionRate = 20;
  final _rateController = TextEditingController();

  // --- broadcast ---
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  // audience : 'ALL' | 'PATIENTS' | 'PSYCHOLOGISTS'
  String _audience = 'ALL';
  bool _sending = false;
  String? _sendError;
  String? _sendSuccess;

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  @override
  void dispose() {
    _rateController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // ── commission ──────────────────────────────────────────────────────────────

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

  // ── broadcast ────────────────────────────────────────────────────────────────

  Future<void> _sendBroadcast() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      setState(
          () => _sendError = 'Le titre et le message sont obligatoires.');
      return;
    }

    setState(() {
      _sending = true;
      _sendError = null;
      _sendSuccess = null;
    });

    try {
      final sent = await _adminService.broadcastNotification(
        title: title,
        message: message,
        audience: _audience,
      );
      if (!mounted) return;
      setState(() {
        _sendSuccess = 'Annonce envoyée à $sent destinataire(s).';
        _titleController.clear();
        _messageController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = 'Envoi échoué : $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Paramètres',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 16),

          // carte profil admin
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
                  child: Icon(Icons.admin_panel_settings,
                      color: AppColors.tealDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session?.pseudo ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(session?.role.label ?? '',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── SECTION 1 : Réglages plateforme ─────────────────────────────────
          _SectionHeader(
            icon: Icons.tune,
            title: 'Réglages plateforme',
          ),
          const SizedBox(height: 4),
          const Text(
            'Pourcentage prélevé sur chaque paiement réussi — le reste revient '
            'au psychologue.',
            style: TextStyle(
                color: AppColors.muted, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
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
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            suffixText: '%',
                            labelText: 'Commission',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _savingRate ? null : _saveRate,
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal),
                        child: _savingRate
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Enregistrer'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 28),

          // ── SECTION 2 : Modération ───────────────────────────────────────────
          _SectionHeader(
            icon: Icons.shield_outlined,
            title: 'Modération',
          ),
          const SizedBox(height: 4),
          const Text(
            'Consultez et traitez les signalements soumis par les patients '
            'à l\'encontre de psychologues.',
            style: TextStyle(
                color: AppColors.muted, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.flag_outlined,
            label: 'Signalements psychologues',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const _ReportsPage()),
            ),
          ),
          const SizedBox(height: 28),

          // ── SECTION 3 : Communication ────────────────────────────────────────
          _SectionHeader(
            icon: Icons.campaign_outlined,
            title: 'Communication',
          ),
          const SizedBox(height: 4),
          const Text(
            'Envoyez une annonce qui apparaîtra dans le centre de notifications '
            'des utilisateurs ciblés.',
            style: TextStyle(
                color: AppColors.muted, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 14),

          // sélecteur d'audience
          Row(
            children: [
              _AudienceChip(
                label: 'Tous',
                value: 'ALL',
                selected: _audience == 'ALL',
                onTap: () => setState(() => _audience = 'ALL'),
              ),
              const SizedBox(width: 8),
              _AudienceChip(
                label: 'Patients',
                value: 'PATIENTS',
                selected: _audience == 'PATIENTS',
                onTap: () => setState(() => _audience = 'PATIENTS'),
              ),
              const SizedBox(width: 8),
              _AudienceChip(
                label: 'Psys',
                value: 'PSYCHOLOGISTS',
                selected: _audience == 'PSYCHOLOGISTS',
                onTap: () => setState(() => _audience = 'PSYCHOLOGISTS'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // titre
          TextField(
            controller: _titleController,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: 'Titre de l\'annonce',
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.tealMid)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (_) => setState(() {
              _sendError = null;
              _sendSuccess = null;
            }),
          ),
          const SizedBox(height: 8),

          // corps du message
          TextField(
            controller: _messageController,
            maxLines: 4,
            maxLength: 400,
            decoration: InputDecoration(
              labelText: 'Message',
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.tealMid)),
              contentPadding: const EdgeInsets.all(14),
            ),
            onChanged: (_) => setState(() {
              _sendError = null;
              _sendSuccess = null;
            }),
          ),
          const SizedBox(height: 4),

          // feedback
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_sendError!,
                    style: const TextStyle(
                        color: AppColors.rose, fontSize: 12)),
              ),
            ),
          if (_sendSuccess != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.teal, size: 16),
                    const SizedBox(width: 8),
                    Text(_sendSuccess!,
                        style: const TextStyle(
                            color: AppColors.tealDark, fontSize: 12)),
                  ],
                ),
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _sendBroadcast,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Envoyer l\'annonce'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // déconnexion
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

// page plein écran signalements accessible depuis la section Modération
class _ReportsPage extends StatelessWidget {
  const _ReportsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signalements')),
      body: const AdminReportsTab(),
    );
  }
}

// ── widgets locaux ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.teal, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.teal, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.teal : AppColors.tealMid),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
