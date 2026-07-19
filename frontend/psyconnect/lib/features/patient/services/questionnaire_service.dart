import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/questionnaire_models.dart';

class QuestionnaireService {
  QuestionnaireService({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  // PATIENT : historique complet (pending + completed)
  Future<List<Questionnaire>> getMyQuestionnaires() async {
    final json = await _api.get(ApiConstants.myQuestionnaires);
    return (json as List)
        .map((e) => Questionnaire.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // PATIENT : questionnaires en attente de réponse
  Future<List<Questionnaire>> getMyPendingQuestionnaires() async {
    final json = await _api.get(ApiConstants.myPendingQuestionnaires);
    return (json as List)
        .map((e) => Questionnaire.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // PATIENT : soumet ses réponses (liste d'entiers 0-3)
  Future<Questionnaire> answerQuestionnaire(
      int questionnaireId, List<int> answers) async {
    final json = await _api.post(
      ApiConstants.questionnaireAnswers(questionnaireId),
      body: {'answers': answers},
    );
    return Questionnaire.fromJson(json as Map<String, dynamic>);
  }

  // PSY : envoie un questionnaire à un patient
  Future<Questionnaire> sendQuestionnaire({
    required QuestionnaireType type,
    required int patientId,
    int? appointmentId,
  }) async {
    final json = await _api.post(
      ApiConstants.questionnaires,
      body: {
        'type': type == QuestionnaireType.PHQ9 ? 'PHQ9' : 'GAD7',
        'patientId': patientId,
        if (appointmentId != null) 'appointmentId': appointmentId,
      },
    );
    return Questionnaire.fromJson(json as Map<String, dynamic>);
  }

  // PSY : historique questionnaires d'un patient
  Future<List<Questionnaire>> getPatientQuestionnaires(int patientId) async {
    final json =
        await _api.get(ApiConstants.patientQuestionnaires(patientId));
    return (json as List)
        .map((e) => Questionnaire.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
