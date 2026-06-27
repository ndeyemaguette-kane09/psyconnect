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

    @Column(nullable = false)
    private String languages;

    @Column(nullable = false)
    private String specialty;

    @Column(nullable = false)
    private int yearsOfExperience;

    private String city;

    @Column(nullable = false)
    private Boolean available = true;

    @Column(nullable = false)
    private Double rating = 0.0;

    private int totalReviews;

    @Column(nullable = false)
    private Boolean profileVerified = false;

    // profileVerified=false ne distingue pas "en attente" de "refusé" donc
    // on a besoin d'un champ séparé pour le refus admin. Le default Postgres
    // évite l'échec de l'ALTER TABLE sur les lignes déjà existantes.
    @Column(nullable = false, columnDefinition = "boolean default false")
    private Boolean rejected = false;

    @Column(nullable = false)
    private String licenseNumber;

    private Integer consultationPrice;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    // Justificatif (diplôme / carte pro) : nom de fichier généré par
    // FileStorageService + content-type d'origine, pour le téléchargement.
    private String licenseDocumentPath;

    private String licenseDocumentContentType;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    public PsychologistProfile() {
    }


    // Getters and Setters
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
    public int getYearsOfExperience() {
        return yearsOfExperience;
    }
    public void setYearsOfExperience(int yearsOfExperience) {
        this.yearsOfExperience = yearsOfExperience;
    }
    public String getCity() {
        return city;
    }
    public void setCity(String city) {
        this.city = city;
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
}
