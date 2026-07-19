// erreur unique pour tous les appels API.
//
// le backend renvoie deux types d'erreur :
// - 400 avec { champ: message } pour les erreurs de formulaire
// - 400 avec { "message": "..." } pour les erreurs metier
//
// fieldErrors est rempli dans le premier cas (pour afficher l'erreur sous
// chaque champ du formulaire), message dans les deux cas.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, String> fieldErrors;
  // Code fonctionnel envoyé par le backend (ex : "ACCOUNT_BANNED").
  // Permet d'identifier précisément le type d'erreur sans analyser le texte.
  final String? errorCode;

  ApiException({
    this.statusCode,
    required this.message,
    this.fieldErrors = const {},
    this.errorCode,
  });

  factory ApiException.network() => ApiException(
        message:
            "Impossible de contacter le serveur. Vérifiez que l'API Gateway "
            "et les services sont bien lancés, et que l'adresse configurée "
            "(ApiConstants.baseUrl) est correcte.",
      );

  factory ApiException.timeout() => ApiException(
        message: 'Le serveur ne répond pas (délai dépassé).',
      );

  @override
  String toString() => message;
}
