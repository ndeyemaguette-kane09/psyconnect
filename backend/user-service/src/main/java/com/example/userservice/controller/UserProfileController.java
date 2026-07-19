package com.example.userservice.controller;

import com.example.userservice.dto.CreateUserProfileRequest;
import com.example.userservice.dto.UpdateUserProfileRequest;
import com.example.userservice.dto.UserProfileResponse;
import com.example.userservice.service.UserProfileService;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/users")
public class UserProfileController {

    private final UserProfileService userProfileService;

    public UserProfileController(
            UserProfileService userProfileService
    ) {
        this.userProfileService = userProfileService;
    }

    @PostMapping
    public ResponseEntity<UserProfileResponse>
    createProfile(
            @Valid @RequestBody
            CreateUserProfileRequest request
    ) {

        UserProfileResponse response =
                userProfileService.createProfile(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserProfileResponse>
    getProfile(
            @PathVariable Long id
    ) {

        UserProfileResponse response =
                userProfileService.getProfile(id);

        return ResponseEntity.ok(response);
    }

    // pareil que pour patient/psy mais pour UserProfile.id
    // utile si l'inscription s'est arretée avant la creation du profil
    @GetMapping("/by-auth-user/{authUserId}")
    public ResponseEntity<UserProfileResponse>
    getProfileByAuthUserId(
            HttpServletRequest httpRequest,
            @PathVariable Long authUserId
    ) {

        return ResponseEntity.ok(
                userProfileService.getProfileByAuthUserId(
                        authUserId,
                        currentAuthUserId(httpRequest)
                )
        );
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserProfileResponse>
    updateProfile(
            @PathVariable Long id,

            @Valid @RequestBody
            UpdateUserProfileRequest request
    ) {

        UserProfileResponse response =
                userProfileService.updateProfile(id, request);

        return ResponseEntity.ok(response);
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
