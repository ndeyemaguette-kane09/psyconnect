import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import 'contact_admin_screen.dart';

// ecran Parametres, pas dans la maquette
// regroupe mode anonyme (sauvegarde backend) et notifications (local)
//
// la langue a demenage dans "Modifier le profil"
//
// design libre : icones en pastille coloree + header degrade
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.userProfileId,
    required this.patientId,
    required this.patientProfile,
  });

  final int userProfileId;
  final int patientId;
  final PatientProfile? patientProfile;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileService = ProfileService();

  late bool _anonymousMode = widget.patientProfile?.anonymousMode ?? false;
  bool _notificationsEnabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    TokenStorage.readNotificationsEnabled().then((v) {
      if (mounted) setState(() => _notificationsEnabled = v);
    });
  }

  Future<void> _persistPatientPrefs() async {
    setState(() => _saving = true);
    try {
      await _profileService.updatePatientProfile(
        widget.patientId,
        CreatePatientProfileRequest(
          userProfileId: widget.userProfileId,
          emergencyContactName: widget.patientProfile?.emergencyContactName,
          emergencyContactPhone: widget.patientProfile?.emergencyContactPhone,
          medicalHistory: widget.patientProfile?.medicalHistory,
          preferredLanguage: widget.patientProfile?.preferredLanguage,
          anonymousMode: _anonymousMode,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'enregistrer ce réglage.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editPseudo() async {
    final auth = context.read<AuthProvider>();
    final current = auth.session?.pseudo ?? '';
    final newPseudo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PseudoSheet(initialValue: current),
    );
    if (newPseudo == null || newPseudo == current || !mounted) return;
    setState(() => _saving = true);
    final ok = await auth.updatePseudo(newPseudo);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Pseudonyme mis à jour.'
              : auth.errorMessage ?? 'Impossible de modifier le pseudonyme.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Paramètres', style: TextStyle(color: AppColors.text)),
        iconTheme: const IconThemeData(color: AppColors.text),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.teal,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Adaptez PsyConnect à vos préférences de confidentialité et de communication.',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: 'Préférences'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.visibility_off_outlined,
                  title: 'Mode anonyme',
                  subtitle: 'Masque votre nom auprès des psychologues',
                  trailing: Switch(
                    value: _anonymousMode,
                    onChanged: (v) {
                      setState(() => _anonymousMode = v);
                      _persistPatientPrefs();
                    },
                  ),
                ),
                _SettingsRow(
                  icon: Icons.badge_outlined,
                  title: 'Pseudonyme',
                  subtitle: context.watch<AuthProvider>().session?.pseudo ??
                      'Nom affiché en mode anonyme',
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: _editPseudo,
                ),
              ],
            ),
            const SizedBox(height: 22),
            SectionHeader(title: 'Notifications'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  title: 'Recevoir des notifications',
                  subtitle: 'Réglage local à cet appareil',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (v) {
                      setState(() => _notificationsEnabled = v);
                      TokenStorage.saveNotificationsEnabled(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SectionHeader(title: 'Aide'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.support_agent_outlined,
                  title: 'Contacter l\'administrateur',
                  subtitle: 'Question, problème technique, autre demande',
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.muted),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ContactAdminScreen(
                        profileId: widget.patientId,
                        role: UserRole.patient,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SectionHeader(title: 'À propos'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.info_outline,
                  title: 'PsyConnect Sénégal',
                  subtitle: 'Version 1.0.0',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.tealLight,
              child: Icon(icon, size: 18, color: AppColors.teal),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _PseudoSheet extends StatefulWidget {
  const _PseudoSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_PseudoSheet> createState() => _PseudoSheetState();
}

class _PseudoSheetState extends State<_PseudoSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.tealMid,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Modifier votre pseudonyme',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'C\'est ce nom que verra le psychologue quand le mode anonyme est activé.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Pseudonyme',
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirm,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
