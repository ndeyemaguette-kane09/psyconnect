/// Exception unifiée pour les erreurs d'appel API.
///
/// Le backend Spring Boot renvoie deux formes d'erreur (cf.
/// GlobalExceptionHandler des services) :
/// - 400 avec une map { champ: message } pour les erreurs de validation
///   (@Valid sur les DTO de RegisterRequest, etc.)
/// - 400 avec { "message": "..." } pour les RuntimeException métier
///
/// [fieldErrors] est rempli dans le premier cas (utile pour afficher les
/// erreurs sous chaque champ de formulaire), [message] dans les deux cas.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, String> fieldErrors;

  ApiException({
    this.statusCode,
    required this.message,
    this.fieldErrors = const {},
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
