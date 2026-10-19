import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../../auth/services/profile_service.dart';
import '../../journal/screens/journal_screen.dart';
import '../../payment/models/wallet_models.dart';
import '../../payment/screens/wallet_screen.dart';
import '../../payment/services/wallet_service.dart';
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
  final _walletService = WalletService();

  bool _loading = true;
  UserProfile? _userProfile;
  PatientProfile? _patientProfile;
  int _pendingQuestionnaireCount = 0;
  Wallet? _wallet;

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

    Wallet? wallet;
    if (patientId != null) {
      try {
        wallet = await _walletService.getWallet(patientId);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _wallet = wallet;
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
    final displayName = name.isEmpty ? (session?.pseudo ?? '') : name;
    final patientId = session?.profileId;
    final userProfileId = session?.userProfileId;
    final contactLine = [
      if (_userProfile?.phoneNumber.isNotEmpty == true)
        _userProfile!.phoneNumber,
      if (_userProfile?.city != null && _userProfile!.city!.isNotEmpty)
        _userProfile!.city!,
    ].join(' · ');

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    AppAvatar(name: displayName, size: 80),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(fontSize: 24),
                          ),
                          if (contactLine.isNotEmpty)
                            Text(
                              contactLine,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.muted,
                              ),
                            ),
                          if (_userProfile != null && patientId != null)
                            InkWell(
                              onTap: _openEditProfile,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Modifier mon profil',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.teal,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const SectionHeader(
                title: 'Mon suivi',
                padding: EdgeInsets.symmetric(horizontal: 4),
              ),
              const SizedBox(height: 10),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _NavRow(
                      icon: Icons.book_outlined,
                      label: 'Mon journal',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const JournalScreen()),
                      ),
                    ),
                    _NavRow(
                      icon: Icons.assignment_outlined,
                      label: 'Questionnaires',
                      iconColor: AppColors.goldDark,
                      iconBackground: AppColors.goldLight,
                      badge: _pendingQuestionnaireCount > 0
                          ? _pendingQuestionnaireCount
                          : null,
                      onTap: () => Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const QuestionnaireHistoryScreen(),
                            ),
                          )
                          .then((_) => _load()),
                    ),
                    _NavRow(
                      icon: Icons.medical_information_outlined,
                      label: 'Antécédents médicaux',
                      iconColor: AppColors.text,
                      iconBackground: AppColors.sand,
                      onTap: patientId == null
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MedicalHistoryScreen(
                                    patientId: patientId,
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
              if (patientId != null) ...[
                const SizedBox(height: 14),
                Material(
                  color: AppColors.teal,
                  borderRadius: AppRadius.mdAll,
                  child: InkWell(
                    borderRadius: AppRadius.mdAll,
                    onTap: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => WalletScreen(patientId: patientId),
                          ),
                        )
                        .then((_) => _load()),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Mon solde',
                                  style: TextStyle(
                                    color: Color(0xFFC9DCD2),
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  _wallet == null
                                      ? 'Voir mon portefeuille'
                                      : '${_wallet!.balance.toStringAsFixed(0)} F',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white, size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              const SectionHeader(
                title: 'Contact d\'urgence',
                padding: EdgeInsets.symmetric(horizontal: 4),
              ),
              const SizedBox(height: 6),
              _InfoLine(
                label: 'Nom',
                value: _patientProfile?.emergencyContactName,
              ),
              _InfoLine(
                label: 'Téléphone',
                value: _patientProfile?.emergencyContactPhone,
              ),
              const SizedBox(height: 22),
              const SectionHeader(
                title: 'Mes informations',
                padding: EdgeInsets.symmetric(horizontal: 4),
              ),
              const SizedBox(height: 6),
              _InfoLine(label: 'Ville', value: _userProfile?.city),
              _InfoLine(label: 'Pays', value: _userProfile?.country),
              _InfoLine(
                label: 'Langue préférée',
                value: _patientProfile?.preferredLanguage,
              ),
              const SizedBox(height: 18),
              _TextLink(
                label: 'Paramètres',
                onTap: (patientId == null || userProfileId == null)
                    ? null
                    : () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              userProfileId: userProfileId,
                              patientId: patientId,
                              patientProfile: _patientProfile,
                            ),
                          ),
                        )
                        .then((_) => _load()),
              ),
              _TextLink(
                label: 'Se déconnecter',
                color: AppColors.danger,
                onTap: _logout,
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
    this.iconColor = AppColors.teal,
    this.iconBackground = AppColors.tealLight,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final int? badge;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.goldDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$badge à faire',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: AppColors.muted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              empty ? 'Non renseigné' : value!,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: empty ? FontWeight.w500 : FontWeight.w700,
                color: empty ? AppColors.muted : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.label,
    required this.onTap,
    this.color = AppColors.text,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: onTap == null ? AppColors.faint : color,
          ),
        ),
      ),
    );
  }
}
