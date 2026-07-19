import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../../auth/services/profile_service.dart';
import '../../journal/screens/journal_screen.dart';
import '../../payment/screens/wallet_screen.dart';
import '../services/questionnaire_service.dart';
import 'edit_profile_screen.dart';
import 'medical_history_screen.dart';
import 'questionnaire_history_screen.dart';
import 'settings_screen.dart';

// Onglet Profil du patient : informations personnelles, édition, navigation
// vers les paramètres et déconnexion.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _profileService = ProfileService();
  final _questionnaireService = QuestionnaireService();

  bool _loading = true;
  UserProfile? _userProfile;
  PatientProfile? _patientProfile;
  int _pendingQuestionnaireCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Lu avant l'await pour éviter d'utiliser context après une opération asynchrone.
    final session = context.read<AuthProvider>().session;
    final userProfileId = session?.userProfileId;
    final patientId = session?.profileId;

    UserProfile? userProfile;
    PatientProfile? patientProfile;
    try {
      if (userProfileId != null) {
        userProfile = await _profileService.getUserProfileById(userProfileId);
      }
      if (patientId != null) {
        patientProfile = await _profileService.getPatientProfileById(patientId);
      }
    } catch (_) {
      // Profil indisponible : on conserve ce qui a déjà été chargé.
    }

    // questionnaires en attente — pour le badge sur le bouton profil
    int pendingCount = 0;
    try {
      final pending = await _questionnaireService.getMyPendingQuestionnaires();
      pendingCount = pending.length;
    } catch (_) {
      // Échec silencieux : le badge reste à 0.
    }

    if (!mounted) return;
    setState(() {
      _userProfile = userProfile;
      _patientProfile = patientProfile;
      _pendingQuestionnaireCount = pendingCount;
      _loading = false;
    });
  }

  Future<void> _openEditProfile() async {
    final session = context.read<AuthProvider>().session;
    final userProfileId = session?.userProfileId;
    final patientId = session?.profileId;
    if (userProfileId == null || patientId == null || _userProfile == null) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          userProfileId: userProfileId,
          patientId: patientId,
          userProfile: _userProfile!,
          patientProfile: _patientProfile,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final name = _userProfile != null
        ? '${_userProfile!.firstName} ${_userProfile!.lastName}'.trim()
        : (session?.pseudo ?? '');

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('Profil', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? (session?.pseudo ?? '') : name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16),
                          ),
                          if (_userProfile?.phoneNumber.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(_userProfile!.phoneNumber,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Informations', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: (_userProfile == null || session?.profileId == null)
                        ? null
                        : _openEditProfile,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoTile(
                icon: Icons.location_city_outlined,
                label: 'Ville',
                value: _userProfile?.city,
              ),
              _InfoTile(
                icon: Icons.public_outlined,
                label: 'Pays',
                value: _userProfile?.country,
              ),
              _InfoTile(
                icon: Icons.language_outlined,
                label: 'Langue préférée',
                value: _patientProfile?.preferredLanguage,
              ),
              const SizedBox(height: 20),
              Text('Contact d\'urgence',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _InfoTile(
                icon: Icons.contact_phone_outlined,
                label: 'Nom',
                value: _patientProfile?.emergencyContactName,
              ),
              _InfoTile(
                icon: Icons.phone_outlined,
                label: 'Téléphone',
                value: _patientProfile?.emergencyContactPhone,
              ),
              const SizedBox(height: 20),
              _NavRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Mon solde PsyConnect',
                onTap: session?.profileId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                WalletScreen(patientId: session!.profileId!),
                          ),
                        ),
              ),
              const SizedBox(height: 10),
              _NavRow(
                icon: Icons.book_outlined,
                label: 'Mon journal',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JournalScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _NavRow(
                icon: Icons.assignment_outlined,
                label: 'Mes questionnaires',
                badge: _pendingQuestionnaireCount > 0
                    ? _pendingQuestionnaireCount
                    : null,
                onTap: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const QuestionnaireHistoryScreen(),
                      ),
                    )
                    .then((_) => _load()),
              ),
              const SizedBox(height: 10),
              _NavRow(
                icon: Icons.medical_information_outlined,
                label: 'Antécédents médicaux',
                onTap: session?.profileId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MedicalHistoryScreen(
                              patientId: session!.profileId!,
                            ),
                          ),
                        ),
              ),
              const SizedBox(height: 10),
              _NavRow(
                icon: Icons.settings_outlined,
                label: 'Paramètres',
                onTap: (session?.profileId == null || session?.userProfileId == null)
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              userProfileId: session!.userProfileId!,
                              patientId: session.profileId!,
                              patientProfile: _patientProfile,
                            ),
                          ),
                        ).then((_) => _load()),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: AppColors.rose),
                label: const Text('Se déconnecter',
                    style: TextStyle(color: AppColors.rose)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.rose),
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  // nombre affiché dans un badge rouge à droite (null = pas de badge)
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.teal, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.rose,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final display = (value == null || value!.isEmpty) ? 'Non renseigné' : value!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.teal, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(display, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
