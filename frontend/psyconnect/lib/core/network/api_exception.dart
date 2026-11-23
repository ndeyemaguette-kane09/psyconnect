// erreur unique pour tous les appels API
// fieldErrors : erreurs de formulaire { champ: message }, message : erreur métier
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, String> fieldErrors;
  // Code fonctionnel envoyé par le backend (ex : "ACCOUNT_BANNED").
  final String? errorCode;

  ApiException({
    this.statusCode,
    required this.message,
    this.fieldErrors = const {},
    this.errorCode,
  });

  factory ApiException.network() => ApiException(
        message:
            'Connexion impossible. Vérifiez votre connexion internet et réessayez.',
      );

  factory ApiException.timeout() => ApiException(
        message: 'Le service met trop de temps à répondre. Réessayez dans un instant.',
      );

  @override
  String toString() => message;
}

String userMessage(Object error) => error is ApiException
    ? error.message
    : 'Une erreur inattendue est survenue. Réessayez.';
