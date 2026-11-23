import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/loading_state.dart';
import 'core/widgets/offline_banner.dart';
import 'core/widgets/touch_indicator_overlay.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/home/screens/home_screen.dart';

// cercles de toucher : true pour filmer une démo
const bool kShowTouchIndicators = false;

final _navigatorKey = GlobalKey<NavigatorState>();

class PsyConnectApp extends StatelessWidget {
  const PsyConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final auth = AuthProvider()..restoreSession();
        ApiClient.onSessionRevoked = () {
          if (auth.session == null) return;
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          auth.logout();
        };
        return auth;
      },
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'PsyConnect Sénégal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // builder s'applique à tout le contenu de l'app, par-dessus les routes
        builder: (ctx, child) {
          final content = OfflineBanner(child: child!);
          return kShowTouchIndicators
              ? TouchIndicatorOverlay(child: content)
              : content;
        },
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
          body: AppLoadingState(label: 'Préparation de votre espace sécurisé…'),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const SplashScreen();
    }
  }
}
