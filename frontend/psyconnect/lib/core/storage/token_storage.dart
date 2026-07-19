import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// garde la session (token + infos de base) dans le stockage securise, pour
// pas avoir a se reconnecter chaque fois qu'on ouvre l'app
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

  // persiste l'id du UserProfile et l'id du profil metier (PatientProfile.id
  // ou PsychologistProfile.id selon le role). ce dernier est necessaire
  // partout ou on a besoin du "patientId"/"psychologistId" (ex POST
  // /appointments), distinct de l'authUserId du JWT.
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

  // preference locale (rien cote backend) : afficher ou non le badge
  // de notifs non lues. stockee avec la session pour pas ajouter
  // une dependance juste pour un booleen.
  static Future<void> saveNotificationsEnabled(bool enabled) =>
      _storage.write(key: _keyNotificationsEnabled, value: enabled.toString());

  static Future<bool> readNotificationsEnabled() async {
    final raw = await _storage.read(key: _keyNotificationsEnabled);
    return raw != 'false'; // active par defaut si jamais regle
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
