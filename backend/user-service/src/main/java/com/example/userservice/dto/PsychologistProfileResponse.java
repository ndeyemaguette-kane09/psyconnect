package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
public class PsychologistProfileResponse {

    private Long id;

    private String firstName;

    private String lastName;

    private String profilePicture;

    private String bio;

    private String specialty;

    private Integer yearsOfExperience;

    private Integer consultationPrice;

    private String languages;

    private String city;

    private Double rating;

    private Integer totalReviews;

    private Boolean available;

    private Long authUserId;

    private Boolean profileVerified;

    private Boolean rejected;

    private String licenseNumber;

    private LocalDateTime createdAt;

    // On n'expose jamais le chemin de fichier brut (détail d'implémentation
    // serveur) : juste un booléen pour savoir si un justificatif existe, le
    // contenu se récupère via GET /psychologists/{id}/license-document.
    private Boolean hasLicenseDocument;
}