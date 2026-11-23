import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:psyconnect/features/admin/screens/admin_shell.dart';
import 'package:psyconnect/features/auth/providers/auth_provider.dart';

Future<void> pumpAdminShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MaterialApp(home: AdminShell()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('utilise un menu latéral sur grand écran', (tester) async {
    await pumpAdminShell(tester, const Size(1400, 900));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomAppBar), findsNothing);
    expect(find.text('Validations'), findsWidgets);
  });

  testWidgets('garde la barre du bas sur téléphone', (tester) async {
    await pumpAdminShell(tester, const Size(400, 850));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(BottomAppBar), findsOneWidget);
  });
}
