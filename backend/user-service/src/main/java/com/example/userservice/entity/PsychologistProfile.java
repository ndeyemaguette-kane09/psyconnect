package com.example.userservice.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;


@Entity
@Table(name = "psychologist_profiles")
public class PsychologistProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "user_profile_id", nullable = false)
    private UserProfile userProfile;

    private Long authUserId;

    private String bio;

    // Langues parlées : non demandées à l'inscription (uniquement modifiables
    // depuis "Profil > Modifier"), donc doit rester optionnel en base.
    // c'était nullable=false par erreur → création de profil impossible
    // pour tout nouveau psychologue (corrigé le 2026-06-30)
    private String languages;

    @Column(nullable = false)
    private String specialty;

    // Optionnel à l'inscription (champ "Années d'expérience" sans validator
    // côté Flutter) : Integer (pas int) pour accepter null sans NPE au
    // unboxing, et sans contrainte NOT NULL en base (corrigé le 2026-06-30,
    // même bug que languages/licenseNumber)
    private Integer yearsOfExperience;

    private String city;

    // adresse precise du cabinet, pour les patients qui veulent s'y rendre
    // physiquement (consultation type "physical"). facultatif, distinct de city
    private String address;

    @Column(nullable = false)
    private Boolean available = true;

    @Column(nullable = false)
    private Double rating = 0.0;

    private int totalReviews;

    @Column(nullable = false)
    private Boolean profileVerified = false;

    // Champ séparé pour le refus : sinon on ne peut pas distinguer "en attente" et "refusé"
    @Column(nullable = false, columnDefinition = "boolean default false")
    private Boolean rejected = false;

    // Numéro de licence : optionnel à l'inscription côté Flutter, à ne pas
    // confondre avec le justificatif (fichier) qui, lui, est obligatoire.
    // c'était nullable=false par erreur, même bug que languages (2026-06-30)
    private String licenseNumber;

    private Integer consultationPrice;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    // Nom du fichier justificatif (généré par FileStorageService) et son type
    private String licenseDocumentPath;

    private String licenseDocumentContentType;

    // mode urgence : le psy active ce flag pour indiquer qu'il est dispo
    // immédiatement (sans RDV). le patient peut alors l'appeler directement.
    @Column(nullable = false, columnDefinition = "boolean default false")
    private Boolean availableForEmergency = false;

    // consultation solidaire : si true, le psy propose sa séance d'urgence
    // gratuitement (pas de débit sur le wallet patient)
    @Column(nullable = false, columnDefinition = "boolean default false")
    private Boolean offersFreeSessions = false;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    public PsychologistProfile() {
    }


    public Long getId() {
        return id;
    }
    public void setId(Long id) {
        this.id = id;
    }
    public UserProfile getUserProfile() {
        return userProfile;
    }

    public void setUserProfile(UserProfile userProfile) {
        this.userProfile = userProfile;
    }
    public Long getAuthUserId() {
        return authUserId;
    }
    public void setAuthUserId(Long authUserId) {
        this.authUserId = authUserId;
    }
    public String getBio() {
        return bio;
    }
    public void setBio(String bio) {
        this.bio = bio;
    }
    public String getLanguages() {
        return languages;
    }
    public void setLanguages(String languages) {
        this.languages = languages;
    }
    public String getSpecialty() {
        return specialty;
    }
    public void setSpecialty(String specialty) {
        this.specialty = specialty;
    }
    public Integer getYearsOfExperience() {
        return yearsOfExperience;
    }
    public void setYearsOfExperience(Integer yearsOfExperience) {
        this.yearsOfExperience = yearsOfExperience;
    }
    public String getCity() {
        return city;
    }
    public void setCity(String city) {
        this.city = city;
    }
    public String getAddress() {
        return address;
    }
    public void setAddress(String address) {
        this.address = address;
    }
    public Boolean getAvailable() {
        return available;
    }

    public void setAvailable(Boolean available) {
        this.available = available;
    }
    public Double getRating() {
        return rating;
    }
    public void setRating(Double rating) {
        this.rating = rating;
    }
    public int getTotalReviews() {
        return totalReviews;
    }
    public void setTotalReviews(int totalReviews) {
        this.totalReviews = totalReviews;   
    }
    public Boolean getProfileVerified() {
        return profileVerified;
    }
    public void setProfileVerified(Boolean profileVerified) {
        this.profileVerified = profileVerified;
    }
    public Boolean getRejected() {
        return rejected;
    }
    public void setRejected(Boolean rejected) {
        this.rejected = rejected;
    }
    public String getLicenseNumber() {
        return licenseNumber;
    }
    public void setLicenseNumber(String licenseNumber) {
        this.licenseNumber = licenseNumber; 
    }
    public Integer getConsultationPrice() {
        return consultationPrice;
    }
    public void setConsultationPrice(Integer consultationPrice) {
        this.consultationPrice = consultationPrice;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public String getLicenseDocumentPath() {
        return licenseDocumentPath;
    }

    public void setLicenseDocumentPath(String licenseDocumentPath) {
        this.licenseDocumentPath = licenseDocumentPath;
    }

    public String getLicenseDocumentContentType() {
        return licenseDocumentContentType;
    }

    public void setLicenseDocumentContentType(String licenseDocumentContentType) {
        this.licenseDocumentContentType = licenseDocumentContentType;
    }

    public Boolean getAvailableForEmergency() {
        return availableForEmergency;
    }

    public void setAvailableForEmergency(Boolean availableForEmergency) {
        this.availableForEmergency = availableForEmergency;
    }

    public Boolean getOffersFreeSessions() {
        return offersFreeSessions;
    }

    public void setOffersFreeSessions(Boolean offersFreeSessions) {
        this.offersFreeSessions = offersFreeSessions;
    }
}
