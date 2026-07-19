import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/services/psychologist_service.dart';
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
    final name = _me != null ? _me!.fullName : (session?.pseudo ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (_me != null)
            IconButton(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier le profil',
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              else ...[
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.tealLight,
                        child: Icon(Icons.person,
                            color: AppColors.tealDark, size: 38),
                      ),
                      const SizedBox(height: 12),
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(_me?.specialty ?? '',
                          style: const TextStyle(color: AppColors.muted)),
                      if (_me?.rating != null && _me!.rating! > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: AppColors.gold, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_me!.rating!.toStringAsFixed(1)} '
                              '(${_me!.totalReviews ?? 0} avis)',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Informations professionnelles'),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Numéro de licence',
                    value: _me?.licenseNumber),
                const SizedBox(height: 10),
                _InfoRow(
                    icon: Icons.work_history_outlined,
                    label: "Années d'expérience",
                    value: _me?.yearsOfExperience?.toString()),
                const SizedBox(height: 10),
                _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Prix consultation',
                    value: _me?.consultationPrice != null
                        ? '${_me!.consultationPrice} FCFA'
                        : null),
                const SizedBox(height: 10),
                _InfoRow(
                    icon: Icons.translate_outlined,
                    label: 'Langues parlées',
                    value: _me?.languages),
                const SizedBox(height: 10),
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Ville',
                    value: _me?.city),
                const SizedBox(height: 10),
                _InfoRow(
                    icon: Icons.map_outlined,
                    label: 'Adresse du cabinet',
                    value: _me?.address),
                const SizedBox(height: 10),
                _InfoRow(
                    icon: Icons.description_outlined,
                    label: 'Bio',
                    value: _me?.bio),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.verified_outlined,
                  label: 'Justificatif',
                  value: _me?.hasLicenseDocument == true
                      ? 'Fourni'
                      : 'Non fourni',
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Planning'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final psychologistId =
                          context.read<AuthProvider>().session?.profileId;
                      if (psychologistId == null) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PsyAvailabilityScreen(
                            psychologistId: psychologistId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_today_outlined,
                        color: AppColors.teal),
                    label: const Text('Mes disponibilités',
                        style: TextStyle(color: AppColors.teal)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.teal),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: AppColors.rose),
                    label: const Text('Se déconnecter',
                        style: TextStyle(color: AppColors.rose)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.rose),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontWeight: FontWeight.w700, color: AppColors.tealDark, fontSize: 13),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                hasValue ? value! : 'Non renseigné',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: hasValue ? AppColors.tealDark : AppColors.muted,
                  fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
