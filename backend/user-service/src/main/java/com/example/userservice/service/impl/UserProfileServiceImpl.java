package com.example.userservice.service.impl;

import com.example.userservice.dto.CreateUserProfileRequest;
import com.example.userservice.dto.UpdateUserProfileRequest;
import com.example.userservice.dto.UserProfileResponse;
import com.example.userservice.entity.UserProfile;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.UserProfileRepository;
import com.example.userservice.service.UserProfileService;

import org.springframework.stereotype.Service;

@Service
public class UserProfileServiceImpl
        implements UserProfileService {

    private final UserProfileRepository userProfileRepository;

    public UserProfileServiceImpl(
            UserProfileRepository userProfileRepository
    ) {
        this.userProfileRepository = userProfileRepository;
    }

    @Override
    public UserProfileResponse createProfile(
            CreateUserProfileRequest request
    ) {

        UserProfile userProfile = new UserProfile();

        userProfile.setAuthUserId(
                request.getAuthUserId()
        );

        userProfile.setFirstName(
                request.getFirstName()
        );

        userProfile.setLastName(
                request.getLastName()
        );

        userProfile.setPhoneNumber(
                request.getPhoneNumber()
        );

        userProfile.setProfilePicture(
                request.getProfilePicture()
        );

        userProfile.setGender(
                request.getGender()
        );

        userProfile.setDateOfBirth(
                request.getDateOfBirth()
        );

        userProfile.setAddress(
                request.getAddress()
        );

        userProfile.setCity(
                request.getCity()
        );

        userProfile.setCountry(
                request.getCountry()
        );

        UserProfile savedProfile =
                userProfileRepository.save(userProfile);

        return mapToResponse(savedProfile);
    }

    @Override
    public UserProfileResponse getProfile(Long id) {

        UserProfile userProfile =
                userProfileRepository.findById(id)

                .orElseThrow(() ->
                        new RuntimeException(
                                "User profile not found"
                        )
                );

        return mapToResponse(userProfile);
    }

    @Override
    public UserProfileResponse getProfileByAuthUserId(
            Long authUserId,
            Long callerAuthUserId
    ) {

        if (!authUserId.equals(callerAuthUserId)) {
            throw new ForbiddenOperationException(
                    "Ce profil ne vous appartient pas"
            );
        }

        UserProfile userProfile =
                userProfileRepository.findByAuthUserId(authUserId)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "User profile not found"
                                )
                        );

        return mapToResponse(userProfile);
    }

    @Override
    public UserProfileResponse updateProfile(
            Long id,
            UpdateUserProfileRequest request
    ) {

        UserProfile userProfile =
                userProfileRepository.findById(id)

                .orElseThrow(() ->
                        new RuntimeException(
                                "User profile not found"
                        )
                );

        userProfile.setFirstName(
                request.getFirstName()
        );

        userProfile.setLastName(
                request.getLastName()
        );

        userProfile.setPhoneNumber(
                request.getPhoneNumber()
        );

        userProfile.setProfilePicture(
                request.getProfilePicture()
        );

        userProfile.setGender(
                request.getGender()
        );

        userProfile.setDateOfBirth(
                request.getDateOfBirth()
        );

        userProfile.setAddress(
                request.getAddress()
        );

        userProfile.setCity(
                request.getCity()
        );

        userProfile.setCountry(
                request.getCountry()
        );

        UserProfile updatedProfile =
                userProfileRepository.save(userProfile);

        return mapToResponse(updatedProfile);
    }

    private UserProfileResponse mapToResponse(
            UserProfile userProfile
    ) {

        UserProfileResponse response =
                new UserProfileResponse();

        response.setId(userProfile.getId());

        response.setFirstName(
                userProfile.getFirstName()
        );

        response.setLastName(
                userProfile.getLastName()
        );

        response.setPhoneNumber(
                userProfile.getPhoneNumber()
        );

        response.setProfilePicture(
                userProfile.getProfilePicture()
        );

        response.setGender(
                userProfile.getGender()
        );

        response.setCity(
                userProfile.getCity()
        );

        response.setCountry(
                userProfile.getCountry()
        );
        response.setAddress(
        userProfile.getAddress()
);

        return response;
    }
}