/// Correspond à CreateUserProfileRequest côté user-service (POST /users).
/// `authUserId` doit être l'id renvoyé par /auth/login (AuthSession.userId).
class CreateUserProfileRequest {
  final int authUserId;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? address;
  final String? city;
  final String? country;

  CreateUserProfileRequest({
    required this.authUserId,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.gender,
    this.dateOfBirth,
    this.address,
    this.city,
    this.country,
  });

  Map<String, dynamic> toJson() => {
        'authUserId': authUserId,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        if (gender != null) 'gender': gender,
        if (dateOfBirth != null)
          'dateOfBirth':
              '${dateOfBirth!.year.toString().padLeft(4, '0')}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}',
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
      };
}

/// Correspond à UpdateUserProfileRequest côté user-service (PUT /users/{id}).
/// On envoie systématiquement toutes les valeurs connues (pas seulement les
/// champs modifiés) : le endpoint réutilise un DTO de type "create" côté
/// backend et son comportement en cas de champ omis n'est pas garanti.
class UpdateUserProfileRequest {
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? gender;
  final String? address;
  final String? city;
  final String? country;

  UpdateUserProfileRequest({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.gender,
    this.address,
    this.city,
    this.country,
  });

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        if (gender != null) 'gender': gender,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
      };
}

/// Correspond à UserProfileResponse côté user-service.
class UserProfile {
  final int id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? gender;
  final String? city;
  final String? country;
  final String? address;

  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.gender,
    this.city,
    this.country,
    this.address,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: (json['id'] as num).toInt(),
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String? ?? '',
        gender: json['gender'] as String?,
        city: json['city'] as String?,
        country: json['country'] as String?,
        address: json['address'] as String?,
      );
}

/// Correspond à CreatePatientProfileRequest côté user-service (POST /patients).
class CreatePatientProfileRequest {
  final int userProfileId;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? medicalHistory;
  final String? preferredLanguage;
  final bool? anonymousMode;

  CreatePatientProfileRequest({
    required this.userProfileId,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.medicalHistory,
    this.preferredLanguage,
    this.anonymousMode,
  });

  Map<String, dynamic> toJson() => {
        'userProfileId': userProfileId,
        if (emergencyContactName != null)
          'emergencyContactName': emergencyContactName,
        if (emergencyContactPhone != null)
          'emergencyContactPhone': emergencyContactPhone,
        if (medicalHistory != null) 'medicalHistory': medicalHistory,
        if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
        if (anonymousMode != null) 'anonymousMode': anonymousMode,
      };
}

/// Correspond à PatientProfileResponse côté user-service (GET /patients/{id}).
class PatientProfile {
  final int id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? medicalHistory;
  final String? preferredLanguage;
  final bool anonymousMode;

  PatientProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.medicalHistory,
    this.preferredLanguage,
    this.anonymousMode = false,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
        id: (json['id'] as num).toInt(),
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        profilePicture: json['profilePicture'] as String?,
        emergencyContactName: json['emergencyContactName'] as String?,
        emergencyContactPhone: json['emergencyContactPhone'] as String?,
        medicalHistory: json['medicalHistory'] as String?,
        preferredLanguage: json['preferredLanguage'] as String?,
        anonymousMode: json['anonymousMode'] as bool? ?? false,
      );
}

/// Correspond à CreatePsychologistProfileRequest côté user-service
/// (POST /psychologists).
class CreatePsychologistProfileRequest {
  final int userProfileId;
  final String specialty;
  final String? bio;
  final int? yearsOfExperience;
  final int? consultationPrice;
  final String? languages;
  final String? city;
  final String? licenseNumber;

  CreatePsychologistProfileRequest({
    required this.userProfileId,
    required this.specialty,
    this.bio,
    this.yearsOfExperience,
    this.consultationPrice,
    this.languages,
    this.city,
    this.licenseNumber,
  });

  Map<String, dynamic> toJson() => {
        'userProfileId': userProfileId,
        'specialty': specialty,
        if (bio != null) 'bio': bio,
        if (yearsOfExperience != null) 'yearsOfExperience': yearsOfExperience,
        if (consultationPrice != null) 'consultationPrice': consultationPrice,
        if (languages != null) 'languages': languages,
        if (city != null) 'city': city,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
      };
}
