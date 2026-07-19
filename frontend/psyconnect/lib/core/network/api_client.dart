import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

// Résultat d'un fichier téléchargé : octets bruts et type MIME associé
// (permet de distinguer image et PDF avant d'ouvrir le fichier).
class DownloadedFile {
  const DownloadedFile({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

// Client HTTP centralisé : construit les URL, injecte le token d'authentification,
// décode le JSON et convertit les erreurs réseau ou backend en ApiException.
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
    Duration? timeout,
  }) async {
    return _send(() async => _client
        .post(
          _uri(path),
          headers: await _headers(withAuth: withAuth),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(timeout ?? ApiConstants.timeout));
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

  Future<dynamic> delete(String path, {bool withAuth = true}) async {
    return _send(() async => _client
        .delete(_uri(path), headers: await _headers(withAuth: withAuth))
        .timeout(ApiConstants.timeout));
  }

  // Requête multipart avec champs texte et fichier optionnel (ex : signalement
  // patient). Spring exige MULTIPART_FORM_DATA_VALUE même sans pièce jointe,
  // d'où le multipart systématique même si filePath est null.
  Future<dynamic> postMultipartFields(
    String path, {
    Map<String, String> fields = const {},
    String? filePath,
    String? fileFieldName,
    String? fileNameOverride,
    bool withAuth = true,
    Duration? timeout,
  }) async {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path));

      final headers = await _headers(withAuth: withAuth);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.fields.addAll(fields);

      if (filePath != null && fileFieldName != null) {
        request.files.add(await http.MultipartFile.fromPath(
          fileFieldName,
          filePath,
          filename: fileNameOverride,
          contentType: _guessMediaType(fileNameOverride ?? filePath),
        ));
      }

      final streamedResponse = await _client
          .send(request)
          .timeout(timeout ?? ApiConstants.timeout);
      return http.Response.fromStream(streamedResponse);
    });
  }

  // Envoie un fichier en multipart/form-data (justificatif du psychologue).
  // Le timeout est délibérément plus long : un fichier de plusieurs Mo peut
  // dépasser 15 s sur un réseau mobile.
  Future<dynamic> postMultipart(
    String path, {
    required String fieldName,
    required String filePath,
    String? fileNameOverride,
    bool withAuth = true,
    Duration? timeout,
  }) async {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path));

      // MultipartRequest définit lui-même son Content-Type boundary.
      final headers = await _headers(withAuth: withAuth);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        filename: fileNameOverride,
        // Sans ce forçage, http déduirait le Content-Type depuis l'extension
        // de filePath — le chemin temporaire renvoyé par file_picker. Sur iOS,
        // ce chemin n'a souvent aucune extension (cache du picker), ce qui
        // produit "application/octet-stream" et provoque un rejet backend.
        // On préfère déduire le type depuis le nom original du fichier
        // (fileNameOverride), dont l'extension est fiable.
        contentType: _guessMediaType(fileNameOverride ?? filePath),
      ));

      final streamedResponse = await _client
          .send(request)
          .timeout(timeout ?? ApiConstants.timeout);
      return http.Response.fromStream(streamedResponse);
    });
  }

  // Déduit le Content-Type depuis l'extension (PDF/PNG/JPEG : les seuls
  // formats acceptés par user-service pour le justificatif). Retourne null
  // si l'extension est inconnue, laissant http choisir lui-même.
  MediaType? _guessMediaType(String nameOrPath) {
    final lower = nameOrPath.toLowerCase();
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return null;
  }

  // Télécharge un fichier binaire (ex : justificatif psy) sans passer par
  // _send, qui tenterait de le décoder en JSON.
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
      // Erreur métier : { "message": "…" }, éventuellement accompagnée de
      // timestamp/status. On vérifie la présence de la clé "message" plutôt
      // que la taille de la map pour distinguer ce format des autres.
      if (decoded.containsKey('message')) {
        final errorCode = decoded['errorCode']?.toString();
        return ApiException(
          statusCode: statusCode,
          message: decoded['message']?.toString() ?? 'Erreur inconnue',
          errorCode: errorCode,
        );
      }

      // Page d'erreur par défaut de Spring Boot sans handler personnalisé :
      // {timestamp, status, error, path} sans clé "message". On ne la traite
      // pas comme une erreur de validation pour éviter d'afficher un timestamp brut.
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
      // {fields: {champ: message}} ou directement {champ: message} à plat.
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
