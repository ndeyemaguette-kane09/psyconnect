import 'user_role.dart';

// correspond a RegisterRequest cote auth-service. le role est fixe par
// l'endpoint appele (/auth/register/patient ou /psy), pas besoin de l'envoyer ici
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

// correspond a AuthResponse (reponse /auth/login). userProfileId et profileId
// viennent jamais du login, remplis apres coup par AuthProvider (onboarding
// ou resolution par authUserId). profileId = patientId/psychologistId selon le role
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

  AuthSession copyWith({int? userProfileId, int? profileId, String? pseudo}) =>
      AuthSession(
        token: token,
        role: role,
        userId: userId,
        pseudo: pseudo ?? this.pseudo,
        userProfileId: userProfileId ?? this.userProfileId,
        profileId: profileId ?? this.profileId,
      );
}
