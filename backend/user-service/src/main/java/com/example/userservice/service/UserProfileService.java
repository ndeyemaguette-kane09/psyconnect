package com.example.userservice.service;

import com.example.userservice.dto.CreateUserProfileRequest;
import com.example.userservice.dto.UpdateUserProfileRequest;
import com.example.userservice.dto.UserProfileResponse;

public interface UserProfileService {

    UserProfileResponse createProfile(
            CreateUserProfileRequest request
    );

    UserProfileResponse getProfile(
            Long id
    );

    UserProfileResponse getProfileByAuthUserId(
            Long authUserId,
            Long callerAuthUserId
    );

    UserProfileResponse updateProfile(
            Long id,
            UpdateUserProfileRequest request
    );
}