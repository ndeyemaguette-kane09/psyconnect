package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class PatientProfileResponse {

    private Long id;

    private String firstName;

    private String lastName;

    private String profilePicture;

    private String city;

    private String emergencyContactName;

    private String emergencyContactPhone;

    private String medicalHistory;

    private String preferredLanguage;

    private Boolean anonymousMode;

    private Long authUserId;
}