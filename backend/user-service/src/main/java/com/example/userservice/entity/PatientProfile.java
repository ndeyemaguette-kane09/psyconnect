package com.example.userservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
@Table(name = "patient_profiles")   
public class PatientProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "user_profile_id", nullable = false)
    private UserProfile userProfile;

    private Long authUserId;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    private Boolean anonymousMode = false;

    private String emergencyContactName;

    private String emergencyContactPhone;

    private String medicalHistory;

    private String preferredLanguage;

    // le solde du patient, en F CFA
    @Column(columnDefinition = "double precision default 0")
    private Double walletBalance = 0.0;

    public PatientProfile() {
    }

    
}