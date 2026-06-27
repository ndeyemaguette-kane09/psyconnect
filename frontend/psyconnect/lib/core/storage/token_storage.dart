import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistance sécurisée de la session (JWT + infos minimales de l'utilisateur
/// connecté), pour éviter de devoir se reconnecter à chaque ouverture de l'app.
class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage();

  static const _keyToken = 'auth_token';
  static const _keyRole = 'auth_role';
  static const _keyUserId = 'auth_user_id';
  static const _keyPseudo = 'auth_pseudo';
  static const _keyUserProfileId = 'auth_user_profile_id';
  static const _keyProfileId = 'auth_profile_id';

  static Future<void> saveSession({
    required String token,
    required String role,
    required int userId,
    required String pseudo,
  }) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyRole, value: role),
      _storage.write(key: _keyUserId, value: userId.toString()),
      _storage.write(key: _keyPseudo, value: pseudo),
    ]);
  }

  /// Persiste l'id du UserProfile (user-service) et l'id du profil métier
  /// (PatientProfile.id ou PsychologistProfile.id selon le rôle). Ce dernier
  /// est nécessaire pour tout appel qui a besoin du "patientId"/"psychologistId"
  /// (ex. POST /appointments), distinct de l'authUserId du JWT.
  static Future<void> saveProfileIds({
    int? userProfileId,
    int? profileId,
  }) async {
    await Future.wait([
      if (userProfileId != null)
        _storage.write(key: _keyUserProfileId, value: userProfileId.toString())
      else
        _storage.delete(key: _keyUserProfileId),
      if (profileId != null)
        _storage.write(key: _keyProfileId, value: profileId.toString())
      else
        _storage.delete(key: _keyProfileId),
    ]);
  }

  static Future<String?> readToken() => _storage.read(key: _keyToken);

  static Future<String?> readRole() => _storage.read(key: _keyRole);

  static Future<int?> readUserId() async {
    final raw = await _storage.read(key: _keyUserId);
    return raw == null ? null : int.tryParse(raw);
  }

  static Future<String?> readPseudo() => _storage.read(key: _keyPseudo);

  static Future<int?> readUserProfileId() async {
    final raw = await _storage.read(key: _keyUserProfileId);
    return raw == null ? null : int.tryParse(raw);
  }

  static Future<int?> readProfileId() async {
    final raw = await _storage.read(key: _keyProfileId);
    return raw == null ? null : int.tryParse(raw);
  }

  static const _keyNotificationsEnabled = 'settings_notifications_enabled';

  /// Préférence locale (pas de backend pour ça) : afficher ou non le badge
  /// de notifications non lues / proposer l'écran Notifications en avant.
  /// Persistée via le même secure storage que la session pour éviter
  /// d'ajouter une nouvelle dépendance (ex. shared_preferences) juste pour
  /// un seul booléen.
  static Future<void> saveNotificationsEnabled(bool enabled) =>
      _storage.write(key: _keyNotificationsEnabled, value: enabled.toString());

  static Future<bool> readNotificationsEnabled() async {
    final raw = await _storage.read(key: _keyNotificationsEnabled);
    return raw != 'false'; // activé par défaut si jamais réglé.
  }

  static Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyRole),
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyPseudo),
      _storage.delete(key: _keyUserProfileId),
      _storage.delete(key: _keyProfileId),
    ]);
  }
}
