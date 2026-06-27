/// Correspond à PsychologistProfileResponse côté user-service
/// (GET /psychologists, GET /psychologists/{id}).
class PsychologistProfile {
  final int id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String? bio;
  final String specialty;
  final int? yearsOfExperience;
  final int? consultationPrice;
  final String? languages;
  final String? city;
  final double? rating;
  final int? totalReviews;
  final bool available;
  // Utilisé par l'écran admin de validation des psychologues (cf.
  // AdminController#setPsychologistVerified) — sans intérêt côté patient,
  // mais doit rester sur ce modèle partagé pour éviter une duplication.
  final bool profileVerified;
  // Distinct de profileVerified=false : un profil "rejected" a été refusé
  // explicitement par un admin (cf. AdminController#setPsychologistRejected),
  // alors que profileVerified=false seul peut aussi vouloir dire "jamais
  // encore traité".
  final bool rejected;
  // Champs ajoutés pour la validation admin "concrète" (cf. écran de détail
  // dans admin_validation_tab.dart) : sans intérêt côté patient, mais
  // doivent rester sur ce modèle partagé pour éviter une duplication.
  final String? licenseNumber;
  final DateTime? createdAt;
  final bool hasLicenseDocument;

  PsychologistProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.bio,
    required this.specialty,
    this.yearsOfExperience,
    this.consultationPrice,
    this.languages,
    this.city,
    this.rating,
    this.totalReviews,
    this.available = true,
    this.profileVerified = true,
    this.rejected = false,
    this.licenseNumber,
    this.createdAt,
    this.hasLicenseDocument = false,
  });

  String get fullName => 'Dr. $firstName $lastName';

  factory PsychologistProfile.fromJson(Map<String, dynamic> json) =>
      PsychologistProfile(
        id: (json['id'] as num).toInt(),
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        profilePicture: json['profilePicture'] as String?,
        bio: json['bio'] as String?,
        specialty: json['specialty'] as String? ?? '',
        yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt(),
        consultationPrice: (json['consultationPrice'] as num?)?.toInt(),
        languages: json['languages'] as String?,
        city: json['city'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        totalReviews: (json['totalReviews'] as num?)?.toInt(),
        available: json['available'] as bool? ?? true,
        profileVerified: json['profileVerified'] as bool? ?? true,
        rejected: json['rejected'] as bool? ?? false,
        licenseNumber: json['licenseNumber'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        hasLicenseDocument: json['hasLicenseDocument'] as bool? ?? false,
      );
}
