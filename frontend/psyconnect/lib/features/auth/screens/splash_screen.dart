import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/user_role.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _stagger(double begin, double end, Widget child) {
    final interval = Interval(begin, end, curve: AppMotion.emphasized);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, c) {
        final t = interval.transform(_ctrl.value).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - t)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(color: AppColors.tealDark),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(flex: 3),

                          _stagger(0.00, 0.45, const _LogoSection()),

                          const SizedBox(height: 26),

                          _stagger(
                            0.12,
                            0.58,
                            Text(
                              'Votre santé mentale,\nentre de bonnes mains.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          _stagger(0.22, 0.68, const _KeyPoints()),

                          const Spacer(flex: 4),

                          _stagger(
                            0.34,
                            0.80,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.white
                                            .withValues(alpha: 0.18),
                                      ),
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'VOUS ÊTES',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.6,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.white
                                            .withValues(alpha: 0.18),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                IntrinsicHeight(
                                  child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _RoleCard(
                                        icon: Icons.favorite_border_rounded,
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
                                        sublabel: "J'exerce et\nj'accompagne",
                                        onTap: () => _goToRegister(
                                            context, UserRole.psychologist),
                                      ),
                                    ),
                                  ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          _stagger(
                            0.46,
                            0.92,
                            _GhostButton(
                              label: "J'ai déjà un compte",
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
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

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 1.5,
            ),
          ),
          child: SvgPicture.asset('assets/images/psyconnect_mark.svg'),
        ),
        const SizedBox(height: 20),
        Text(
          'PsyConnect',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontSize: 38,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Text(
            'SÉNÉGAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyPoints extends StatelessWidget {
  const _KeyPoints();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _KeyChip(icon: Icons.lock_outline_rounded, text: 'Anonymat garanti'),
        _KeyChip(icon: Icons.location_on_outlined, text: 'Dakar · Thiès · Saint-Louis'),
        _KeyChip(icon: Icons.phone_android_rounded, text: 'Wave & Orange Money'),
      ],
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 13),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
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
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppMotion.fast,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _pressed ? 0.24 : 0.16),
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.34),
              width: 1.4,
            ),
          ),
          child: Column(
            children: [
              Icon(widget.icon, color: Colors.white, size: 26),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.sublabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

