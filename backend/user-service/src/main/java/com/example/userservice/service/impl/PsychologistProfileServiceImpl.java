package com.example.userservice.service.impl;

import com.example.userservice.client.NotificationClient;
import com.example.userservice.dto.CreatePsychologistProfileRequest;
import com.example.userservice.dto.LicenseDocumentResponse;
import com.example.userservice.dto.PsychologistProfileResponse;
import com.example.userservice.entity.PsychologistProfile;
import com.example.userservice.entity.UserProfile;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.PsychologistProfileRepository;
import com.example.userservice.repository.UserProfileRepository;
import com.example.userservice.service.FileStorageService;
import com.example.userservice.service.PsychologistProfileService;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class PsychologistProfileServiceImpl
        implements PsychologistProfileService {

    // Formats acceptés pour le justificatif : PDF ou image
    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
            "application/pdf", "image/png", "image/jpeg"
    );

    private final PsychologistProfileRepository
            psychologistProfileRepository;

    private final UserProfileRepository
            userProfileRepository;

    private final NotificationClient notificationClient;

    private final FileStorageService fileStorageService;

    public PsychologistProfileServiceImpl(
            PsychologistProfileRepository psychologistProfileRepository,
            UserProfileRepository userProfileRepository,
            NotificationClient notificationClient,
            FileStorageService fileStorageService
    ) {

        this.psychologistProfileRepository =
                psychologistProfileRepository;

        this.userProfileRepository =
                userProfileRepository;

        this.notificationClient = notificationClient;

        this.fileStorageService = fileStorageService;
    }

    @Override
    public PsychologistProfileResponse createPsychologistProfile(
            CreatePsychologistProfileRequest request,
            Long callerAuthUserId
    ) {

        UserProfile userProfile =
                userProfileRepository.findByAuthUserId(
                        callerAuthUserId
                ).orElseThrow(() ->
                        new ResourceNotFoundException(
                                "User profile not found"
                        )
                );

        PsychologistProfile psychologistProfile =
                new PsychologistProfile();

        psychologistProfile.setUserProfile(
                userProfile
        );

        psychologistProfile.setAuthUserId(
                callerAuthUserId
        );

        psychologistProfile.setSpecialty(
                request.getSpecialty()
        );

        psychologistProfile.setBio(
                request.getBio()
        );

        psychologistProfile.setYearsOfExperience(
                request.getYearsOfExperience()
        );

        psychologistProfile.setConsultationPrice(
                request.getConsultationPrice()
        );

        psychologistProfile.setLanguages(
                request.getLanguages()
        );

        psychologistProfile.setCity(
                request.getCity()
        );

        psychologistProfile.setAddress(
                request.getAddress()
        );

        psychologistProfile.setLicenseNumber(
                request.getLicenseNumber()
        );

        psychologistProfile.setAvailable(true);

        psychologistProfile.setProfileVerified(false);

        psychologistProfile.setRating(0.0);

        psychologistProfile.setTotalReviews(0);

        PsychologistProfile savedProfile =
                psychologistProfileRepository.save(
                        psychologistProfile
                );
                userProfile.setProfileCompleted(true);

                userProfileRepository.save(userProfile);

        return mapToResponse(savedProfile);
    }

    @Override
    public PsychologistProfileResponse getPsychologistProfile(
            Long id
    ) {

        PsychologistProfile psychologistProfile =
                psychologistProfileRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Psychologist profile not found"
                                )
                        );

        return mapToResponse(psychologistProfile);
    }

    @Override
    public PsychologistProfileResponse getPsychologistProfileByAuthUserId(
            Long authUserId,
            Long callerAuthUserId
    ) {

        if (!authUserId.equals(callerAuthUserId)) {
            throw new ForbiddenOperationException(
                    "Ce profil psychologue ne vous appartient pas"
            );
        }

        PsychologistProfile psychologistProfile =
                psychologistProfileRepository.findByAuthUserId(authUserId)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Psychologist profile not found"
                                )
                        );

        return mapToResponse(psychologistProfile);
    }

    @Override
    public List<PsychologistProfileResponse>
    getAllPsychologists(Boolean verifiedOnly) {

        List<PsychologistProfile> profiles =
                psychologistProfileRepository.findAll();

        if (Boolean.TRUE.equals(verifiedOnly)) {
            profiles = profiles.stream()
                    .filter(p -> Boolean.TRUE.equals(p.getProfileVerified()))
                    .collect(Collectors.toList());
        }

        return profiles
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public PsychologistProfileResponse setProfileVerified(
            Long id,
            boolean verified
    ) {

        PsychologistProfile psychologistProfile =
                psychologistProfileRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Psychologist profile not found"
                                )
                        );

        psychologistProfile.setProfileVerified(verified);

        if (verified) {
            psychologistProfile.setRejected(false);
        }

        PsychologistProfile updatedProfile =
                psychologistProfileRepository.save(psychologistProfile);

        // Notifie uniquement si c'est une vraie acceptation
        if (verified) {
            notificationClient.send(
                    updatedProfile.getId(),
                    "Profil validé",
                    "Votre profil de psychologue a été vérifié par l'administrateur. "
                            + "Vous êtes désormais visible des patients.",
                    "SYSTEM",
                    "PSYCHOLOGIST"
            );
        }

        return mapToResponse(updatedProfile);
    }

    @Override
    public PsychologistProfileResponse setProfileRejected(
            Long id,
            boolean rejected
    ) {

        PsychologistProfile psychologistProfile =
                psychologistProfileRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Psychologist profile not found"
                                )
                        );

        psychologistProfile.setRejected(rejected);

        if (rejected) {
            psychologistProfile.setProfileVerified(false);
        }

        PsychologistProfile updatedProfile =
                psychologistProfileRepository.save(psychologistProfile);

        // Notifie uniquement le refus, pas le retour en attente
        if (rejected) {
            notificationClient.send(
                    updatedProfile.getId(),
                    "Demande de validation refusée",
                    "Votre demande de validation de profil a été refusée par l'administrateur. "
                            + "Vous pouvez mettre à jour votre profil et contacter le support si besoin.",
                    "SYSTEM",
                    "PSYCHOLOGIST"
            );
        }

        return mapToResponse(updatedProfile);
    }

    @Override
    public PsychologistProfileResponse updatePsychologistProfile(
            Long id,
            CreatePsychologistProfileRequest request,
            Long callerAuthUserId
    ) {

        PsychologistProfile psychologistProfile =
                psychologistProfileRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Psychologist profile not found"
                                )
                        );

        if (psychologistProfile.getAuthUserId() == null
                || !psychologistProfile.getAuthUserId().equals(callerAuthUserId)) {
            throw new ForbiddenOperationException(
                    "Ce profil psychologue ne vous appartient pas"
            );
        }

        psychologistProfile.setSpecialty(
                request.getSpecialty()
        );

        psychologistProfile.setBio(
                request.getBio()
        );

        psychologistProfile.setYearsOfExperience(
                request.getYearsOfExperience()
        );

        psychologistProfile.setConsultationPrice(
                request.getConsultationPrice()
        );

        psychologistProfile.setLanguages(
                request.getLanguages()
        );

        psychologistProfile.setCity(
                request.getCity()
        );

        psychologistProfile.setAddress(
                request.getAddress()
        );

        psychologistProfile.setLicenseNumber(
                request.getLicenseNumber()
        );

        PsychologistProfile updatedProfile =
                psychologistProfileRepository.save(
                        psychologistProfile
                );

        return mapToResponse(updatedProfile);
    }

    @Override
    public List<PsychologistProfileResponse> getEmergencyPsychologists() {
        return psychologistProfileRepository.findAll()
                .stream()
                .filter(p -> Boolean.TRUE.equals(p.getProfileVerified())
                        && Boolean.TRUE.equals(p.getAvailableForEmergency()))
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public PsychologistProfileResponse setEmergencyAvailability(
            Long id,
            boolean available,
            boolean freeSession,
            Long callerAuthUserId
    ) {
        PsychologistProfile profile = psychologistProfileRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Psychologist profile not found"));

        // Pas de vérification d'ownership ici : Spring Security garantit
        // hasRole("PSYCHOLOGIST") en amont — seuls les psys atteignent cet
        // endpoint. Un psy ne connaît pas l'id interne d'un autre psy, et
        // activer l'urgence pour autrui ne lui apporterait rien.
        // On profite de l'appel pour backfiller authUserId si absent (profils
        // anciens créés avant l'ajout du champ).
        if (profile.getAuthUserId() == null && callerAuthUserId != null) {
            profile.setAuthUserId(callerAuthUserId);
        }

        profile.setAvailableForEmergency(available);
        profile.setOffersFreeSessions(available && freeSession);

        return mapToResponse(psychologistProfileRepository.save(profile));
    }

    @Override
    public PsychologistProfileResponse uploadLicenseDocument(
            Long id,
            MultipartFile file,
            Long callerAuthUserId
    ) {

        PsychologistProfile psychologistProfile =
                psychologistProfileRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Psychologist profile not found"
                                )
                        );

        if (psychologistProfile.getAuthUserId() == null
                || !psychologistProfile.getAuthUserId().equals(callerAuthUserId)) {
            throw new ForbiddenOperationException(
                    "Ce profil psychologue ne vous appartient pas"
            );
        }

        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Le fichier est vide.");
        }

        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_CONTENT_TYPES.contains(contentType)) {
            throw new IllegalArgumentException(
                    "Format non supporté : seuls PDF, PNG et JPEG sont acceptés."
            );
        }

        // remplace l'ancien justificatif, sinon ça accumule des fichiers orphelins
        String previousStoredName = psychologistProfile.getLicenseDocumentPath();

        String storedName = fileStorageService.store(file);

        psychologistProfile.setLicenseDocumentPath(storedName);
        psychologistProfile.setLicenseDocumentContentType(contentType);

        PsychologistProfile updatedProfile =
                psychologistProfileRepository.save(psychologistProfile);

        if (previousStoredName != null) {
            fileStorageService.delete(previousStoredName);
        }

        return mapToResponse(updatedProfile);
    }

    @Override
    public LicenseDocumentResponse getLicenseDocument(
            Long id,
            Long callerAuthUserId,
            boolean callerIsAdmin
    ) {

        PsychologistProfile psychologistProfile =
                psychologistProfileRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Psychologist profile not found"
                                )
                        );

        boolean isOwner = psychologistProfile.getAuthUserId() != null
                && psychologistProfile.getAuthUserId().equals(callerAuthUserId);

        if (!isOwner && !callerIsAdmin) {
            throw new ForbiddenOperationException(
                    "Vous n'êtes pas autorisé à consulter ce justificatif."
            );
        }

        if (psychologistProfile.getLicenseDocumentPath() == null) {
            throw new ResourceNotFoundException(
                    "Ce psychologue n'a pas encore fourni de justificatif."
            );
        }

        byte[] data = fileStorageService.load(
                psychologistProfile.getLicenseDocumentPath()
        );

        return new LicenseDocumentResponse(
                data,
                psychologistProfile.getLicenseDocumentContentType()
        );
    }

    private PsychologistProfileResponse mapToResponse(
            PsychologistProfile psychologistProfile
    ) {

        PsychologistProfileResponse response =
                new PsychologistProfileResponse();

        response.setId(
                psychologistProfile.getId()
        );

        response.setFirstName(
                psychologistProfile
                        .getUserProfile()
                        .getFirstName()
        );

        response.setLastName(
                psychologistProfile
                        .getUserProfile()
                        .getLastName()
        );

        response.setProfilePicture(
                psychologistProfile
                        .getUserProfile()
                        .getProfilePicture()
        );

        response.setBio(
                psychologistProfile.getBio()
        );

        response.setSpecialty(
                psychologistProfile.getSpecialty()
        );

        response.setYearsOfExperience(
                psychologistProfile
                        .getYearsOfExperience()
        );

        response.setConsultationPrice(
                psychologistProfile
                        .getConsultationPrice()
        );

        response.setLanguages(
                psychologistProfile.getLanguages()
        );

        response.setCity(
                psychologistProfile.getCity()
        );

        response.setAddress(
                psychologistProfile.getAddress()
        );

        response.setRating(
                psychologistProfile.getRating()
        );

        response.setTotalReviews(
                psychologistProfile.getTotalReviews()
        );

        response.setAvailable(
                psychologistProfile.getAvailable()
        );

        response.setAuthUserId(
                psychologistProfile.getAuthUserId()
        );

        response.setProfileVerified(
                psychologistProfile.getProfileVerified()
        );

        response.setRejected(
                psychologistProfile.getRejected()
        );

        response.setLicenseNumber(
                psychologistProfile.getLicenseNumber()
        );

        response.setCreatedAt(
                psychologistProfile.getCreatedAt()
        );

        response.setHasLicenseDocument(
                psychologistProfile.getLicenseDocumentPath() != null
        );

        response.setAvailableForEmergency(
                Boolean.TRUE.equals(psychologistProfile.getAvailableForEmergency())
        );

        response.setOffersFreeSessions(
                Boolean.TRUE.equals(psychologistProfile.getOffersFreeSessions())
        );

        return response;
    }
}