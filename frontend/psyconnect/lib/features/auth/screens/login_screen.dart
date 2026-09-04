import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../home/screens/home_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/error_banner.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (ok && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const _BrandHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (auth.isBannedAccount) ...[
                      const _BannedAccountCard(),
                      const SizedBox(height: 16),
                    ] else if (auth.errorMessage != null) ...[
                      ErrorBanner(message: auth.errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // ── Carte formulaire ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Bon retour', style: theme.textTheme.displaySmall),
                          const SizedBox(height: 4),
                          Text(
                            'Connectez-vous pour retrouver votre espace.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'vous@exemple.sn',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "L'email est requis";
                              }
                              if (!value.contains('@')) return 'Email invalide';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) {
                              if (!auth.isLoading) _submit(auth);
                            },
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Le mot de passe est requis';
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () {
                                      auth.clearError();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                              child: const Text('Mot de passe oublié ?'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed:
                                auth.isLoading ? null : () => _submit(auth),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Se connecter'),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded,
                                          size: 18),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const _ReassuranceRow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── En-tête de marque ────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.tealDark,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 26),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 22),
                tooltip: 'Retour',
              ),
              const SizedBox(width: 2),
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: SvgPicture.asset('assets/images/psyconnect_mark.svg'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PsyConnect',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Espace sécurisé',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReassuranceRow extends StatelessWidget {
  const _ReassuranceRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ReassuranceItem(
            icon: Icons.shield_outlined, label: 'Données\nchiffrées'),
        SizedBox(width: 24),
        _ReassuranceItem(
            icon: Icons.visibility_off_outlined, label: 'Anonymat\npossible'),
        SizedBox(width: 24),
        _ReassuranceItem(
            icon: Icons.verified_user_outlined, label: 'Psychologues\nvérifiés'),
      ],
    );
  }
}

class _ReassuranceItem extends StatelessWidget {
  const _ReassuranceItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.teal),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.muted,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ── Carte affichée quand le compte est suspendu par l'administrateur ─────────
// Remplace le bandeau d'erreur générique. Affiche les coordonnées admin
// pour que l'utilisateur sache qui contacter.

// ⚠️ Mettez à jour les coordonnées admin avant la mise en production.
const _adminEmail = 'admin@psyconnect.sn';
const _adminPhone = '+221 78 000 00 00';

class _BannedAccountCard extends StatelessWidget {
  const _BannedAccountCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.block_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Compte suspendu',
                  style: TextStyle(
                    color: Color(0xFF7A4F00),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre compte a été suspendu par l\'administrateur. '
            'Si vous pensez qu\'il s\'agit d\'une erreur, '
            'contactez-nous :',
            style:
                TextStyle(color: Color(0xFF7A4F00), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          _ContactRow(
            icon: Icons.mail_outline,
            label: _adminEmail,
            onTap: () {
              Clipboard.setData(const ClipboardData(text: _adminEmail));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Adresse copiée'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: _adminPhone,
            onTap: () {
              Clipboard.setData(const ClipboardData(text: _adminPhone));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Numéro copié'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.warning),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7A4F00),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '(copier)',
            style: TextStyle(color: AppColors.warning, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
