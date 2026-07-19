package com.example.userservice.service;

import com.example.userservice.dto.CreatePsychologistProfileRequest;
import com.example.userservice.dto.LicenseDocumentResponse;
import com.example.userservice.dto.PsychologistProfileResponse;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

public interface PsychologistProfileService {

    PsychologistProfileResponse createPsychologistProfile(
            CreatePsychologistProfileRequest request,
            Long callerAuthUserId
    );

    PsychologistProfileResponse getPsychologistProfile(
            Long id
    );

    PsychologistProfileResponse getPsychologistProfileByAuthUserId(
            Long authUserId,
            Long callerAuthUserId
    );

    List<PsychologistProfileResponse> getAllPsychologists(Boolean verifiedOnly);

    PsychologistProfileResponse updatePsychologistProfile(
            Long id,
            CreatePsychologistProfileRequest request,
            Long callerAuthUserId
    );

    // Admin uniquement : valide ou invalide un profil psychologue
    PsychologistProfileResponse setProfileVerified(Long id, boolean verified);

    // Admin uniquement : refuse une demande (distinct de "en attente")
    PsychologistProfileResponse setProfileRejected(Long id, boolean rejected);

    // Liste des psychologues disponibles pour urgence (vérifiés et availableForEmergency=true)
    List<PsychologistProfileResponse> getEmergencyPsychologists();

    // Le psychologue active/désactive son mode urgence (lui seul peut le faire)
    PsychologistProfileResponse setEmergencyAvailability(
            Long id,
            boolean available,
            boolean freeSession,
            Long callerAuthUserId
    );

    // Upload du justificatif, réservé au propriétaire du profil
    PsychologistProfileResponse uploadLicenseDocument(
            Long id,
            MultipartFile file,
            Long callerAuthUserId
    );

    // Récupère le justificatif — propriétaire du profil ou administrateur
    LicenseDocumentResponse getLicenseDocument(
            Long id,
            Long callerAuthUserId,
            boolean callerIsAdmin
    );
}