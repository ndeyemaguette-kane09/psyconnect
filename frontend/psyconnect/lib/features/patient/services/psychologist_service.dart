import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/psychologist_models.dart';

/// Appelle les endpoints de user-service (via l'API Gateway) pour la liste
/// et le détail des psychologues : GET /psychologists, GET /psychologists/{id},
/// ainsi que ml-service pour la recommandation personnalisée.
///
/// Le filtre `?verifiedOnly=true` est appliqué côté serveur (l'admin peut
/// toujours voir tout le monde via son propre écran, qui appelle
/// `/admin/psychologists`, pas ce service) : un patient ne doit jamais voir
/// un psychologue non vérifié (en attente OU explicitement refusé par un
/// admin) : [getAllPsychologists] appelait `/psychologists` sans aucun
/// paramètre et recevait donc la liste complète, refusés inclus. Le reste
/// du filtrage/recherche (ville, langue,
/// spécialité...) reste côté client, faute d'autres query params serveur.
class PsychologistService {
  PsychologistService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<PsychologistProfile>> getAllPsychologists() async {
    final json = await _api
        .get('${ApiConstants.psychologistProfiles}?verifiedOnly=true');
    return (json as List)
        .map((e) => PsychologistProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PsychologistProfile> getPsychologistById(int id) async {
    final json =
        await _api.get('${ApiConstants.psychologistProfiles}/$id');
    return PsychologistProfile.fromJson(json as Map<String, dynamic>);
  }

  /// GET /recommendations/{patientId} (ml-service, via l'API Gateway) :
  /// filtrage de contenu (TF-IDF + similarité cosinus) sur le profil du
  /// patient, combiné à la note du psychologue. La réponse contient des
  /// champs en plus (contentSimilarity, score) que [PsychologistProfile]
  /// ignore simplement — pas besoin d'un modèle dédié côté Flutter.
  ///
  /// Peut lever une [ApiException] si ml-service est indisponible (502) ou
  /// si le patient n'existe pas côté user-service (404) : à l'appelant de
  /// décider d'un repli (cf. [PatientHomeScreen]).
  Future<List<PsychologistProfile>> getRecommendations(
    int patientId, {
    int topN = 5,
  }) async {
    final json = await _api
        .get(ApiConstants.recommendations(patientId, topN: topN));
    final recommendations =
        (json as Map<String, dynamic>)['recommendations'] as List;
    return recommendations
        .map((e) => PsychologistProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
