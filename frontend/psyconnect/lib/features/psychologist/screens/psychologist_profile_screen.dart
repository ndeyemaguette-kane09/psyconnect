import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/screens/contact_admin_screen.dart';
import '../../patient/services/psychologist_service.dart';
import '../../patient/widgets/psychologist_card.dart';
import '../../payment/screens/psy_wallet_screen.dart';
import 'edit_psychologist_profile_screen.dart';
import 'psy_availability_screen.dart';

// ecran "Profil" cote psy, absent de la maquette
// pour voir ses infos et se deconnecter sans passer par la seule icone logout
// accessible via un bouton dans Stats, pas un 6e onglet
class PsychologistProfileScreen extends StatefulWidget {
  const PsychologistProfileScreen({super.key});

  @override
  State<PsychologistProfileScreen> createState() =>
      _PsychologistProfileScreenState();
}

class _PsychologistProfileScreenState
    extends State<PsychologistProfileScreen> {
  final _psychologistService = PsychologistService();

  bool _loading = true;
  String? _error;
  PsychologistProfile? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) {
      setState(() {
        _error = 'Profil psychologue introuvable.';
        _loading = false;
      });
      return;
    }

    try {
      final me = await _psychologistService.getPsychologistById(psychologistId);
      if (!mounted) return;
      setState(() {
        _me = me;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger votre profil.';
        _loading = false;
      });
    }
  }

  Future<void> _editProfile() async {
    if (_me == null) return;
    final session = context.read<AuthProvider>().session;
    final psychologistId = session?.profileId;
    if (psychologistId == null) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPsychologistProfileScreen(
          psychologistId: psychologistId,
          psychologist: _me!,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez vous reconnecter pour accéder à votre compte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  void _push(Widget Function(int psychologistId) builder) {
    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => builder(psychologistId)));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final me = _me;
    final name = me != null ? me.fullName : (session?.pseudo ?? '');
    final subtitle = [
      if (me != null && me.specialty.trim().isNotEmpty) me.specialty.trim(),
      if (me?.city?.trim().isNotEmpty ?? false) me!.city!.trim(),
    ].join(' · ');
    final bio = me?.bio?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (me != null)
            TextButton(
              onPressed: _editProfile,
              child: const Text(
                'Modifier',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else ...[
              Center(
                child: Column(
                  children: [
                    AppAvatar(name: name, size: 96),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        color: AppColors.text,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.muted),
                      ),
                    if (me?.rating != null && me!.rating! > 0)
                      Text(
                        '${me.rating!.toStringAsFixed(1).replaceAll('.', ',')}'
                        ' sur 5 · ${me.totalReviews ?? 0} avis',
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.muted),
                      ),
                    if (me != null && !me.hasLicenseDocument)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Justificatif de diplôme à fournir',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.goldDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Ce que voient vos patients',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _Fact(
                label: 'Prix d\'une séance',
                value: me?.consultationPrice != null
                    ? '${formatPrice(me!.consultationPrice!)} F'
                    : null,
              ),
              _Fact(
                label: 'Expérience',
                value: me?.yearsOfExperience != null
                    ? '${me!.yearsOfExperience} an'
                        '${me.yearsOfExperience! > 1 ? 's' : ''}'
                    : null,
              ),
              _Fact(label: 'Langues', value: me?.languages),
              _Fact(label: 'Cabinet', value: me?.address),
              if (bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    '« $bio »',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: AppColors.text,
                    ),
                  ),
                ),
              if (me?.licenseNumber?.trim().isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Licence ${me!.licenseNumber!.trim()}',
                    style:
                        const TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ),
              const SizedBox(height: 24),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.calendar_today_outlined,
                      tint: AppColors.tealLight,
                      ink: AppColors.teal,
                      title: 'Mes disponibilités',
                      subtitle: 'Les créneaux que vos patients peuvent réserver',
                      onTap: () => _push((id) =>
                          PsyAvailabilityScreen(psychologistId: id)),
                    ),
                    _MenuRow(
                      icon: Icons.account_balance_wallet_outlined,
                      tint: AppColors.goldLight,
                      ink: AppColors.goldDark,
                      title: 'Mon portefeuille',
                      subtitle: 'Revenus et retraits',
                      onTap: () =>
                          _push((id) => PsyWalletScreen(psychologistId: id)),
                    ),
                    _MenuRow(
                      icon: Icons.chat_bubble_outline,
                      tint: AppColors.sand,
                      ink: AppColors.text,
                      title: 'Écrire à l\'équipe',
                      onTap: () => _push((id) => ContactAdminScreen(
                            profileId: id,
                            role: UserRole.psychologist,
                          )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _logout,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  ),
                  child: const Text(
                    'Se déconnecter',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              hasValue ? value!.trim() : 'Non renseigné',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
                color: hasValue ? AppColors.text : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}
