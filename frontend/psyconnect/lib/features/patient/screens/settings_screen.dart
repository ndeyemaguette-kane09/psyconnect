import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/services/profile_service.dart';

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
              padding: EdgeInsets.only(right: 16),
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
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.circular(16),
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
            _SectionLabel('Préférences'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.visibility_off_outlined,
                  title: 'Mode anonyme',
                  subtitle: 'Masque votre nom auprès des psychologues',
                  trailing: Switch(
                    activeColor: AppColors.teal,
                    value: _anonymousMode,
                    onChanged: (v) {
                      setState(() => _anonymousMode = v);
                      _persistPatientPrefs();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionLabel('Notifications'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  title: 'Recevoir des notifications',
                  subtitle: 'Réglage local à cet appareil',
                  trailing: Switch(
                    activeColor: AppColors.teal,
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
            _SectionLabel('À propos'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.info_outline,
                  title: 'PsyConnect Sénégal',
                  // a jour a la main, pas besoin d'un package juste pour ca
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
