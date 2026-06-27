import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../../auth/services/profile_service.dart';
import '../../journal/screens/journal_screen.dart';
import '../../payment/screens/wallet_screen.dart';
import '../services/notification_service.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

/// Contenu de l'onglet "Profil" du parcours patient (cf. maquette v2) —
/// infos civiles + infos patient, édition du profil, accès aux écrans
/// Paramètres et Notifications (aucun des deux n'existe dans la maquette,
/// ajoutés à la demande de l'utilisateur — cf. mémoire projet), et bouton de
/// déconnexion (déplacé ici depuis l'ancien header de [PatientHomeScreen]).
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _profileService = ProfileService();
  final _notificationService = NotificationService();

  bool _loading = true;
  UserProfile? _userProfile;
  PatientProfile? _patientProfile;
  int _unreadNotifCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Lus avant tout `await` : éviter d'utiliser `context` après un gap async.
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
      // Profil indisponible (réseau/serveur) : on affiche l'écran avec ce
      // qu'on a déjà plutôt que de planter.
    }

    if (!mounted) return;
    setState(() {
      _userProfile = userProfile;
      _patientProfile = patientProfile;
      _loading = false;
    });

    unawaited(_refreshUnreadNotifCount());
  }

  // Badge sur la cloche "Notifications", même principe que le badge
  // "messages non lus" des shells (cf. PatientShell) — appel best-effort
  // séparé du reste du chargement du profil : une erreur réseau ici ne doit
  // pas empêcher d'afficher le profil.
  Future<void> _refreshUnreadNotifCount() async {
    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) return;
    try {
      final notifications =
          await _notificationService.getNotificationsByUserId(patientId);
      final unread = notifications.where((n) => !n.isRead).length;
      if (mounted) setState(() => _unreadNotifCount = unread);
    } catch (_) {
      // Échec silencieux : le badge garde sa dernière valeur connue.
    }
  }

  Future<void> _openNotifications(int patientId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(userId: patientId),
      ),
    );
    // Les notifications consultées ont pu être marquées lues pendant que
    // l'écran était ouvert : on rafraîchit le badge au retour.
    if (mounted) _refreshUnreadNotifCount();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Profil', style: Theme.of(context).textTheme.displayMedium),
                IconButton(
                  tooltip: 'Notifications',
                  icon: Badge(
                    isLabelVisible: _unreadNotifCount > 0,
                    label: Text('$_unreadNotifCount'),
                    child: const Icon(Icons.notifications_outlined,
                        color: AppColors.teal),
                  ),
                  onPressed: session?.profileId == null
                      ? null
                      : () => _openNotifications(session!.profileId!),
                ),
              ],
            ),
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
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

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
