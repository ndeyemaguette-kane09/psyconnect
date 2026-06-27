/// Reflète l'enum `Role` de auth-service (backend/auth-service/.../entity/Role.java).
enum UserRole { patient, psychologist, admin }

extension UserRoleX on UserRole {
  /// Valeur attendue par le backend (sérialisation de l'enum Java).
  String get apiValue {
    switch (this) {
      case UserRole.patient:
        return 'PATIENT';
      case UserRole.psychologist:
        return 'PSYCHOLOGIST';
      case UserRole.admin:
        return 'ADMIN';
    }
  }

  String get label {
    switch (this) {
      case UserRole.patient:
        return 'Patient';
      case UserRole.psychologist:
        return 'Psychologue';
      case UserRole.admin:
        return 'Administrateur';
    }
  }

  static UserRole fromApiValue(String value) {
    switch (value.toUpperCase()) {
      case 'PATIENT':
        return UserRole.patient;
      case 'PSYCHOLOGIST':
        return UserRole.psychologist;
      case 'ADMIN':
        return UserRole.admin;
      default:
        throw ArgumentError('Rôle inconnu: $value');
    }
  }
}
