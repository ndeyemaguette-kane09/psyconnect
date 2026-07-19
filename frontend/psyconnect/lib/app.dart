import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/touch_indicator_overlay.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/home/screens/home_screen.dart';

// ── Overlay de touche — mettre false pour désactiver ─────────────────────────
const bool kShowTouchIndicators = true;

class PsyConnectApp extends StatelessWidget {
  const PsyConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..restoreSession(),
      child: MaterialApp(
        title: 'PsyConnect Sénégal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // builder s'applique à tout le contenu de l'app, par-dessus les routes
        builder: kShowTouchIndicators
            ? (ctx, child) => TouchIndicatorOverlay(child: child!)
            : null,
        home: const _Root(),
      ),
    );
  }
}

// choisit l'ecran de depart selon si y'a deja une session
// (restoreSession est lance au-dessus quand on cree le AuthProvider)
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const SplashScreen();
    }
  }
}
