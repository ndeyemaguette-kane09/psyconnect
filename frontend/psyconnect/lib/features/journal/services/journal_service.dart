import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/journal_models.dart';

// appels /journal de user-service. l'identité du patient vient
// du token côté backend, on n'envoie jamais de patientId ici
class JournalService {
  JournalService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<JournalEntry> createEntry(CreateJournalEntryRequest request) async {
    final json = await _api.post(
      ApiConstants.journalEntries,
      body: request.toJson(),
    );
    return JournalEntry.fromJson(json as Map<String, dynamic>);
  }

  Future<List<JournalEntry>> getMyEntries() async {
    final json = await _api.get(ApiConstants.journalEntries);
    return (json as List)
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JournalEntry> updateEntry(
    int entryId,
    CreateJournalEntryRequest request,
  ) async {
    final json = await _api.put(
      ApiConstants.journalEntry(entryId),
      body: request.toJson(),
    );
    return JournalEntry.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteEntry(int entryId) async {
    await _api.delete(ApiConstants.journalEntry(entryId));
  }
}
