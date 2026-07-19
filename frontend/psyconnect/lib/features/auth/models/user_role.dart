// reflete l'enum Role de auth-service
enum UserRole { patient, psychologist, admin }

extension UserRoleX on UserRole {
  // valeur attendue par le backend (serialisation de l'enum Java)
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
