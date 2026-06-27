import 'user_role.dart';

/// Correspond à RegisterRequest côté auth-service.
/// Le rôle est fixé par l'endpoint appelé (/auth/register/patient ou
/// /auth/register/psy), donc pas besoin de l'envoyer ici.
class RegisterAccountRequest {
  final String email;
  final String password;
  final String pseudo;
  final String firstName;
  final String lastName;

  RegisterAccountRequest({
    required this.email,
    required this.password,
    required this.pseudo,
    required this.firstName,
    required this.lastName,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'pseudo': pseudo,
        'firstName': firstName,
        'lastName': lastName,
      };
}

/// Correspond à AuthResponse côté auth-service (réponse de /auth/login).
///
/// [userProfileId] et [profileId] ne viennent jamais de /auth/login (qui ne
/// connaît que l'authUserId) : ils sont renseignés a posteriori par
/// AuthProvider, soit juste après la création du profil (onboarding), soit
/// via une résolution par authUserId (cf. ApiConstants.patientProfileByAuthUser)
/// pour un utilisateur déjà onboardé qui se reconnecte. [profileId] est
/// l'id du PatientProfile ou PsychologistProfile (selon [role]) — c'est le
/// "patientId"/"psychologistId" attendu par appointment-service.
class AuthSession {
  final String token;
  final UserRole role;
  final int userId;
  final String pseudo;
  final int? userProfileId;
  final int? profileId;

  AuthSession({
    required this.token,
    required this.role,
    required this.userId,
    required this.pseudo,
    this.userProfileId,
    this.profileId,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        role: UserRoleX.fromApiValue(json['role'] as String),
        userId: (json['userId'] as num).toInt(),
        pseudo: json['pseudo'] as String,
      );

  AuthSession copyWith({int? userProfileId, int? profileId}) => AuthSession(
        token: token,
        role: role,
        userId: userId,
        pseudo: pseudo,
        userProfileId: userProfileId ?? this.userProfileId,
        profileId: profileId ?? this.profileId,
      );
}
