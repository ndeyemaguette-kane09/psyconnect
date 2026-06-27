import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Résultat d'un téléchargement binaire (cf. [ApiClient.getFile]) : les
/// octets bruts + le content-type renvoyé par le serveur, nécessaire pour
/// savoir comment ouvrir/afficher le fichier côté UI (image vs PDF).
class DownloadedFile {
  const DownloadedFile({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Petit wrapper autour de `http` qui :
/// - préfixe toutes les requêtes avec [ApiConstants.baseUrl] (l'API Gateway),
/// - ajoute automatiquement le header `Authorization: Bearer <token>` si une
///   session est active,
/// - décode le JSON et remonte une [ApiException] cohérente en cas d'erreur,
///   qu'elle vienne du réseau ou du backend (cf. GlobalExceptionHandler côté
///   Spring Boot : { "champ": "message" } ou { "message": "..." }).
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth) {
      final token = await TokenStorage.readToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('${ApiConstants.baseUrl}$path');

  Future<dynamic> get(String path, {bool withAuth = true}) async {
    return _send(() async => _client
        .get(_uri(path), headers: await _headers(withAuth: withAuth))
        .timeout(ApiConstants.timeout));
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    return _send(() async => _client
        .post(
          _uri(path),
          headers: await _headers(withAuth: withAuth),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(ApiConstants.timeout));
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    return _send(() async => _client
        .put(
          _uri(path),
          headers: await _headers(withAuth: withAuth),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(ApiConstants.timeout));
  }

  /// Utilisé par les endpoints admin (PATCH /admin/users/{id}/enabled,
  /// PATCH /admin/psychologists/{id}/verify), qui passent leur paramètre en
  /// query string (?enabled=, ?verified=) plutôt qu'en corps JSON.
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    return _send(() async => _client
        .patch(
          _uri(path),
          headers: await _headers(withAuth: withAuth),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(ApiConstants.timeout));
  }

  /// Utilisé par DELETE /admin/users/{id} (suppression définitive de compte).
  Future<dynamic> delete(String path, {bool withAuth = true}) async {
    return _send(() async => _client
        .delete(_uri(path), headers: await _headers(withAuth: withAuth))
        .timeout(ApiConstants.timeout));
  }

  /// Envoie un fichier en multipart/form-data — utilisé pour le justificatif
  /// psychologue (POST /psychologists/{id}/license-document, champ "file").
  /// Réutilise [_send] (donc la même gestion d'erreurs que les autres
  /// méthodes) en convertissant la réponse streamée en [http.Response].
  Future<dynamic> postMultipart(
    String path, {
    required String fieldName,
    required String filePath,
    String? fileNameOverride,
    bool withAuth = true,
  }) async {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path));

      // Pas de Content-Type ici : MultipartRequest fixe le sien
      // (multipart/form-data; boundary=...), un header JSON resterait sinon
      // et casserait le parsing côté serveur.
      final headers = await _headers(withAuth: withAuth);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        filename: fileNameOverride,
      ));

      final streamedResponse =
          await _client.send(request).timeout(ApiConstants.timeout);
      return http.Response.fromStream(streamedResponse);
    });
  }

  /// Télécharge un binaire (pas du JSON) avec son content-type — utilisé
  /// pour le justificatif psychologue (GET .../license-document). Ne passe
  /// pas par [_send] car celui-ci décode systématiquement le corps en JSON.
  Future<DownloadedFile> getFile(String path, {bool withAuth = true}) async {
    http.Response response;
    try {
      response = await _client
          .get(_uri(path), headers: await _headers(withAuth: withAuth))
          .timeout(ApiConstants.timeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } on http.ClientException {
      throw ApiException.network();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return DownloadedFile(
        bytes: response.bodyBytes,
        contentType:
            response.headers['content-type'] ?? 'application/octet-stream',
      );
    }

    final body = response.body;
    final dynamic decoded = body.isEmpty
        ? null
        : (body.trim().startsWith('{') ? jsonDecode(body) : null);
    throw _toApiException(response.statusCode, decoded);
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request();
    } on TimeoutException {
      throw ApiException.timeout();
    } on http.ClientException {
      // Couvre les erreurs réseau cross-plateforme (DNS, connexion refusée,
      // etc.) sans dépendre de dart:io, qui n'est pas disponible sur le web.
      throw ApiException.network();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network();
    }

    final isJson =
        response.headers['content-type']?.contains('application/json') ??
            false;
    final dynamic decoded = (response.body.isEmpty)
        ? null
        : (isJson || response.body.trim().startsWith('{') ||
                response.body.trim().startsWith('['))
            ? jsonDecode(response.body)
            : response.body;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw _toApiException(response.statusCode, decoded);
  }

  ApiException _toApiException(int statusCode, dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      // Erreur métier auth-service : { "message": "..." } (1 seule clé).
      // Erreur métier user-service (GlobalExceptionHandler.buildResponse) :
      // { "timestamp", "status", "error", "message" } (4 clés) — il faut
      // donc tester la présence de "message", pas la taille de la map,
      // sinon on tombe par erreur dans la branche "champ -> message"
      // ci-dessous et on affiche la valeur de "error" (ex. "Bad Request")
      // au lieu du vrai message métier.
      if (decoded.containsKey('message')) {
        return ApiException(
          statusCode: statusCode,
          message: decoded['message']?.toString() ?? 'Erreur inconnue',
        );
      }

      // Page d'erreur PAR DÉFAUT de Spring Boot/WebFlux (pas de handler
      // custom n'a intercepté l'exception — ex: service indisponible côté
      // gateway, 5xx non géré, filtre de sécurité qui lève avant d'atteindre
      // le contrôleur) : { "timestamp", "status", "error", "path" }, sans
      // "message" ni "fields". Reconnaissable par la présence de "timestamp"
      // + "status" + "path" ensemble. Il ne faut PAS traiter ça comme une
      // map de validation par champ, sinon on affiche le timestamp brut à
      // la place d'un message (bug réel observé : "2026-06-23T22:48:...").
      if (decoded.containsKey('timestamp') &&
          decoded.containsKey('status') &&
          decoded.containsKey('path')) {
        final errorLabel = decoded['error']?.toString();
        return ApiException(
          statusCode: statusCode,
          message: (errorLabel != null && errorLabel.isNotEmpty)
              ? 'Erreur serveur : $errorLabel (code $statusCode).'
              : 'Une erreur est survenue (code $statusCode).',
        );
      }

      // Erreur de validation @Valid, deux formats possibles :
      // - user-service (handleValidationException) : { "timestamp",
      //   "status", "error", "fields": { "champ": "message", ... } }
      // - auth-service (handleValidationExceptions) : { "champ": "message", ... }
      //   directement à plat.
      final rawFields = decoded['fields'];
      final fieldErrors = (rawFields is Map)
          ? rawFields.map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            )
          : decoded.map(
              (key, value) => MapEntry(key, value?.toString() ?? ''),
            );
      return ApiException(
        statusCode: statusCode,
        message: fieldErrors.values.isNotEmpty
            ? fieldErrors.values.first
            : 'Requête invalide.',
        fieldErrors: fieldErrors,
      );
    }

    return ApiException(
      statusCode: statusCode,
      message: 'Une erreur est survenue (code $statusCode).',
    );
  }
}
