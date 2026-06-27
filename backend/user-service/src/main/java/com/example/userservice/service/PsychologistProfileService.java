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

    /**
     * Réservé à l'ADMIN : valide ou invalide le profil d'un psychologue.
     * Valider (verified=true) lève aussi un éventuel refus précédent
     * (rejected repasse à false).
     */
    PsychologistProfileResponse setProfileVerified(Long id, boolean verified);

    /**
     * Réservé à l'ADMIN : refuse explicitement une demande de validation
     * (rejected=true), ou la remet en attente (rejected=false). Distinct de
     * {@link #setProfileVerified} : un profil "en attente" a déjà
     * profileVerified=false, donc sans ce champ "Refuser" serait un no-op.
     */
    PsychologistProfileResponse setProfileRejected(Long id, boolean rejected);

    /**
     * Réservé au propriétaire du profil : envoie/remplace le justificatif
     * (diplôme, carte professionnelle) joint à l'inscription.
     */
    PsychologistProfileResponse uploadLicenseDocument(
            Long id,
            MultipartFile file,
            Long callerAuthUserId
    );

    /**
     * Accessible au propriétaire du profil OU à un ADMIN (pour la
     * validation) : renvoie le contenu binaire du justificatif.
     */
    LicenseDocumentResponse getLicenseDocument(
            Long id,
            Long callerAuthUserId,
            boolean callerIsAdmin
    );
}