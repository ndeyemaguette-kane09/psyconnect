package com.example.authservice.controller;

import com.example.authservice.dto.AuthResponse;
import com.example.authservice.dto.ForgotPasswordRequest;
import com.example.authservice.dto.ForgotPasswordResponse;
import com.example.authservice.dto.LoginRequest;
import com.example.authservice.dto.MessageResponse;
import com.example.authservice.dto.RegisterRequest;
import com.example.authservice.dto.ResetPasswordWithCodeRequest;
import com.example.authservice.dto.UpdatePseudoRequest;
import com.example.authservice.entity.Role;
import com.example.authservice.service.AuthService;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    public ResponseEntity<MessageResponse> register(
            @Valid @RequestBody RegisterRequest request
    ) {
        return ResponseEntity.ok(authService.register(request));
    }

    @PostMapping("/register/patient")
    public ResponseEntity<MessageResponse> registerPatient(
            @Valid @RequestBody RegisterRequest request
    ) {
        request.setRole(Role.PATIENT);
        return ResponseEntity.ok(authService.register(request));
    }

    @PostMapping("/register/psy")
    public ResponseEntity<MessageResponse> registerPsychologist(
            @Valid @RequestBody RegisterRequest request
    ) {
        request.setRole(Role.PSYCHOLOGIST);
        return ResponseEntity.ok(authService.register(request));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(
            @Valid @RequestBody LoginRequest request
    ) {
        return ResponseEntity.ok(authService.login(request));
    }

    @GetMapping("/me")
    public ResponseEntity<AuthResponse> me(Authentication authentication) {
        return ResponseEntity.ok(
                authService.getCurrentUser(authentication.getName())
        );
    }

    @PostMapping("/pseudo")
    public ResponseEntity<MessageResponse> updatePseudo(
            Authentication authentication,
            @Valid @RequestBody UpdatePseudoRequest request
    ) {
        return ResponseEntity.ok(
                authService.updatePseudo(authentication.getName(), request.getPseudo())
        );
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<ForgotPasswordResponse> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request
    ) {
        return ResponseEntity.ok(authService.forgotPassword(request));
    }

    @PostMapping("/reset-password")
    public ResponseEntity<MessageResponse> resetPassword(
            @Valid @RequestBody ResetPasswordWithCodeRequest request
    ) {
        return ResponseEntity.ok(authService.resetPasswordWithCode(request));
    }
}
