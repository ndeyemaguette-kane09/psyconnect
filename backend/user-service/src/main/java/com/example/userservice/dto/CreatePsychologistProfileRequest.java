package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class CreatePsychologistProfileRequest {

    private Long userProfileId;

    private String specialty;

    private String bio;

    private Integer yearsOfExperience;

    private Integer consultationPrice;

    private String languages;

    private String city;

    // adresse precise du cabinet (consultation en presentiel)
    private String address;

    private String licenseNumber;
}