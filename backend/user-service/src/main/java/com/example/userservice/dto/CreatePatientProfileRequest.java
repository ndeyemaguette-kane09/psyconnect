package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class CreatePatientProfileRequest {

    private Long userProfileId;

    private String emergencyContactName;

    private String emergencyContactPhone;

    private String medicalHistory;

    private String preferredLanguage;

    private Boolean anonymousMode;
}