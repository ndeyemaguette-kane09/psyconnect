// correspond a la reponse de user-service pour un psy
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
  // adresse precise du cabinet, affichee au patient pour s'y rendre en presentiel
  final String? address;
  final double? rating;
  final int? totalReviews;
  final bool available;
  // pour l'ecran admin de validation, pas utile cote patient
  // mais reste ici pour pas dupliquer le modele
  final bool profileVerified;
  // rejected = refusé par un admin, c'est pas pareil que juste pas verifié
  final bool rejected;
  // pour la validation admin, pas utile cote patient
  final String? licenseNumber;
  final DateTime? createdAt;
  final bool hasLicenseDocument;
  // mode urgence : le psy est disponible maintenant pour un appel sans RDV
  final bool availableForEmergency;
  // consultation solidaire gratuite proposée par le psy
  final bool offersFreeSessions;

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
    this.address,
    this.rating,
    this.totalReviews,
    this.available = true,
    this.profileVerified = true,
    this.rejected = false,
    this.licenseNumber,
    this.createdAt,
    this.hasLicenseDocument = false,
    this.availableForEmergency = false,
    this.offersFreeSessions = false,
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
        address: json['address'] as String?,
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
        availableForEmergency:
            json['availableForEmergency'] as bool? ?? false,
        offersFreeSessions: json['offersFreeSessions'] as bool? ?? false,
      );
}

// avis anonyme sur un psychologue (note + commentaire facultatif).
// rating == null veut dire "pas d'avis" (cas du GET /review/me sans avis
// existant) : on differencie ce cas plutot que de mettre 0 par defaut
class PsychologistReview {
  final int? rating;
  final String? comment;
  final DateTime? updatedAt;

  PsychologistReview({this.rating, this.comment, this.updatedAt});

  factory PsychologistReview.fromJson(Map<String, dynamic> json) =>
      PsychologistReview(
        rating: (json['rating'] as num?)?.toInt(),
        comment: json['comment'] as String?,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}
