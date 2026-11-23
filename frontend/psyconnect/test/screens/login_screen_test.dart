import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:psyconnect/features/auth/providers/auth_provider.dart';
import 'package:psyconnect/features/auth/screens/login_screen.dart';

Widget loginScreen() {
  return ChangeNotifierProvider(
    create: (_) => AuthProvider(),
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('demande l\'email et le mot de passe quand le formulaire est vide',
      (tester) async {
    await tester.pumpWidget(loginScreen());

    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text("L'email est requis"), findsOneWidget);
    expect(find.text('Le mot de passe est requis'), findsOneWidget);
  });

  testWidgets('refuse un email sans @', (tester) async {
    await tester.pumpWidget(loginScreen());

    await tester.enterText(find.byType(TextFormField).first, 'magui');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Email invalide'), findsOneWidget);
    expect(find.text('Le mot de passe est requis'), findsNothing);
  });

  testWidgets('affiche puis masque le mot de passe', (tester) async {
    await tester.pumpWidget(loginScreen());

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
