import 'package:flutter_test/flutter_test.dart';
import 'package:psyconnect/features/auth/models/user_role.dart';

void main() {
  group('UserRoleX', () {
    test('fait l\'aller-retour avec auth-service pour chaque rôle', () {
      for (final role in UserRole.values) {
        expect(UserRoleX.fromApiValue(role.apiValue), role);
      }
    });

    test('utilise les noms de l\'enum Java', () {
      expect(UserRole.patient.apiValue, 'PATIENT');
      expect(UserRole.psychologist.apiValue, 'PSYCHOLOGIST');
      expect(UserRole.admin.apiValue, 'ADMIN');
    });

    test('ignore la casse', () {
      expect(UserRoleX.fromApiValue('psychologist'), UserRole.psychologist);
    });

    test('rejette un rôle inconnu', () {
      expect(() => UserRoleX.fromApiValue('SUPERADMIN'), throwsArgumentError);
    });
  });
}
