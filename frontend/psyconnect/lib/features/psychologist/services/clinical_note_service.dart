import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/clinical_note_models.dart';

// CRUD notes cliniques privees : reserve au psychologue authentifie, et
// uniquement sur ses propres notes (verifie cote backend, voir
// ClinicalNoteServiceImpl) - jamais d'endpoint cote patient/admin
class ClinicalNoteService {
  ClinicalNoteService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<ClinicalNote>> getMyNotesForPatient(int patientId) async {
    final json = await _api.get(ApiConstants.patientClinicalNotes(patientId));
    return (json as List)
        .map((e) => ClinicalNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClinicalNote> createNote(
    int patientId,
    CreateOrUpdateClinicalNoteRequest request,
  ) async {
    final json = await _api.post(
      ApiConstants.patientClinicalNotes(patientId),
      body: request.toJson(),
    );
    return ClinicalNote.fromJson(json as Map<String, dynamic>);
  }

  Future<ClinicalNote> updateNote(
    int noteId,
    CreateOrUpdateClinicalNoteRequest request,
  ) async {
    final json = await _api.put(
      ApiConstants.clinicalNote(noteId),
      body: request.toJson(),
    );
    return ClinicalNote.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteNote(int noteId) async {
    await _api.delete(ApiConstants.clinicalNote(noteId));
  }
}
