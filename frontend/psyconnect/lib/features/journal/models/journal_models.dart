// correspond a CreateJournalEntryRequest cote user-service. le patient
// est trouve via le token cote backend, pas besoin de patientId ici
class CreateJournalEntryRequest {
  final String content;
  final int? moodRating;

  CreateJournalEntryRequest({required this.content, this.moodRating});

  Map<String, dynamic> toJson() => {
        'content': content,
        'moodRating': moodRating,
      };
}

// correspond a JournalEntryResponse cote user-service
class JournalEntry {
  final int id;
  final String content;
  final int? moodRating;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntry({
    required this.id,
    required this.content,
    this.moodRating,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: (json['id'] as num).toInt(),
        content: json['content'] as String,
        moodRating: (json['moodRating'] as num?)?.toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
