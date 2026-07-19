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

    // adresse precise du cabinet, affichee au patient pour s'y rendre
    private String address;

    private Double rating;

    private Integer totalReviews;

    private Boolean available;

    private Long authUserId;

    private Boolean profileVerified;

    private Boolean rejected;

    private String licenseNumber;

    private LocalDateTime createdAt;

    // pas le chemin du fichier, juste un booléen si y'a un justificatif
    private Boolean hasLicenseDocument;

    // mode urgence : visible de tous pour l'écran SOS patient
    private Boolean availableForEmergency;
    private Boolean offersFreeSessions;
}