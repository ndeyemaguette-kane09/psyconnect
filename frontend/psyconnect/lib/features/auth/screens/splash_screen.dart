import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../models/user_role.dart';
import 'register_screen.dart';
import 'login_screen.dart';

// Écran d'accueil animé — style épuré avec cartes de choix de rôle
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Démarrer l'animation après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Fond dégradé ─────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppColors.splashGradient),
          ),

          // ── Décoration : cercles flottants ────────────────────────────────
          Positioned(
            top: -60, right: -40,
            child: _GlowCircle(size: 220, opacity: 0.07),
          ),
          Positioned(
            top: 100, left: -80,
            child: _GlowCircle(size: 200, opacity: 0.05),
          ),
          Positioned(
            bottom: 200, right: -60,
            child: _GlowCircle(size: 180, opacity: 0.06),
          ),

          // ── Contenu principal animé ───────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 56,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const Spacer(flex: 2),

                              // ── Logo + Titre ────────────────────────────
                              _LogoSection(),

                              const SizedBox(height: 20),

                              // ── Tagline ─────────────────────────────────
                              const Text(
                                'Votre santé mentale, entre de bonnes mains.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // ── 3 points clés discrets ──────────────────
                              const _KeyPoints(),

                              const Spacer(flex: 3),

                              // ── Choix du rôle ───────────────────────────
                              const Text(
                                'Vous êtes…',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: _RoleCard(
                                      icon: Icons.person_outline_rounded,
                                      label: 'Patient',
                                      sublabel: 'Je cherche\nun psychologue',
                                      onTap: () => _goToRegister(
                                          context, UserRole.patient),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _RoleCard(
                                      icon: Icons.psychology_outlined,
                                      label: 'Psychologue',
                                      sublabel: 'J\'exerce et\nj\'accompagne',
                                      onTap: () => _goToRegister(
                                          context, UserRole.psychologist),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // ── Déjà un compte ───────────────────────────
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                ),
                                child: const Text(
                                  "J'ai déjà un compte — Se connecter",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white54,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToRegister(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreen(role: role)),
    );
  }
}

// ── Logo + titre ─────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: SvgPicture.asset('assets/images/psyconnect_mark.svg'),
        ),
        const SizedBox(height: 16),
        Text(
          'PsyConnect',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Sénégal',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w400,
                letterSpacing: 2.0,
              ),
        ),
      ],
    );
  }
}

// ── Points clés discrets ──────────────────────────────────────────────────────

class _KeyPoints extends StatelessWidget {
  const _KeyPoints();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _KeyRow(icon: Icons.lock_outline_rounded,
            text: 'Anonymat garanti — aucun jugement'),
        SizedBox(height: 6),
        _KeyRow(icon: Icons.location_on_outlined,
            text: 'Psys à Dakar, Thiès, Saint-Louis…'),
        SizedBox(height: 6),
        _KeyRow(icon: Icons.phone_android_rounded,
            text: 'Paiement Wave & Orange Money'),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white60, size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ── Carte de rôle ─────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sublabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cercle décoratif flottant ─────────────────────────────────────────────────

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
