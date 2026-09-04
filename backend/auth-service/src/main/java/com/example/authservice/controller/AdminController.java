package com.example.authservice.controller;

import com.example.authservice.dto.AdminStatsResponse;
import com.example.authservice.dto.MessageResponse;
import com.example.authservice.dto.ResetPasswordRequest;
import com.example.authservice.dto.UserAdminResponse;
import com.example.authservice.service.AdminService;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

import java.util.List;

@RestController
@RequestMapping("/admin")
public class AdminController {

    private final AdminService adminService;

    public AdminController(AdminService adminService) {
        this.adminService = adminService;
    }

    @GetMapping("/users")
    public ResponseEntity<List<UserAdminResponse>> listUsers() {
        return ResponseEntity.ok(adminService.listUsers());
    }

    @PatchMapping("/users/{id}/enabled")
    public ResponseEntity<UserAdminResponse> setUserEnabled(
            @PathVariable Long id,
            @RequestParam boolean enabled,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                adminService.setUserEnabled(id, enabled, authentication.getName())
        );
    }

    @DeleteMapping("/users/{id}")
    public ResponseEntity<MessageResponse> deleteUser(
            @PathVariable Long id,
            Authentication authentication
    ) {
        adminService.deleteUser(id, authentication.getName());
        return ResponseEntity.ok(new MessageResponse("Compte supprimé"));
    }

    @PatchMapping("/users/{id}/password")
    public ResponseEntity<UserAdminResponse> resetPassword(
            @PathVariable Long id,
            @Valid @RequestBody ResetPasswordRequest request,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                adminService.resetPassword(id, request.getNewPassword(), authentication.getName())
        );
    }

    @GetMapping("/stats/accounts")
    public ResponseEntity<AdminStatsResponse> getStats() {
        return ResponseEntity.ok(adminService.getStats());
    }
}
