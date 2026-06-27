// Smoke test : vérifie que l'app démarre et affiche l'écran de splash/
// onboarding quand aucune session n'est persistée (cas par défaut en test,
// flutter_secure_storage n'a pas de plateforme réelle mais répond avec des
// valeurs nulles, ce qui correspond à AuthStatus.unauthenticated).

import 'package:flutter_test/flutter_test.dart';

import 'package:psyconnect/app.dart';

void main() {
  testWidgets('Affiche le splash quand aucune session n\'est active',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PsyConnectApp());
    await tester.pumpAndSettle();

    expect(find.text('Je suis un patient'), findsOneWidget);
    expect(find.text('Je suis un psychologue'), findsOneWidget);
  });

  testWidgets('Le bouton "patient" ouvre l\'inscription', (tester) async {
    await tester.pumpWidget(const PsyConnectApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Je suis un patient'));
    await tester.pumpAndSettle();

    expect(find.text('1. Compte'), findsOneWidget);
  });
}
