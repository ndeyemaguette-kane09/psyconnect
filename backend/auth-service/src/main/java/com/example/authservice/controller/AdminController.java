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

/**
 * Endpoints réservés au rôle ADMIN (gestion des comptes utilisateurs).
 * Protégés par {@code SecurityConfig} : {@code /admin/**} exige
 * {@code hasRole("ADMIN")}.
 */
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

    /**
     * Suppression définitive d'un compte (CDC 6.8 : DELETE /admin/users/{id}).
     * Irréversible — contrairement à la désactivation (PATCH .../enabled),
     * qui reste réversible et est l'action recommandée au quotidien.
     */
    @DeleteMapping("/users/{id}")
    public ResponseEntity<MessageResponse> deleteUser(
            @PathVariable Long id,
            Authentication authentication
    ) {
        adminService.deleteUser(id, authentication.getName());
        return ResponseEntity.ok(new MessageResponse("Compte supprimé"));
    }

    /**
     * Réinitialisation forcée du mot de passe d'un compte par l'admin (CDC
     * 4.3 : utile quand l'utilisateur a perdu l'accès à son email, en
     * l'absence d'un flux self-service "mot de passe oublié").
     */
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

    // Renommé /stats -> /stats/accounts : user-service et appointment-service
    // exposent chacun leur propre /admin/stats, ce qui rendrait le routage
    // gateway ambigu si les 3 chemins restaient identiques (cf. api-gateway
    // application.properties, routes admin-*).
    @GetMapping("/stats/accounts")
    public ResponseEntity<AdminStatsResponse> getStats() {
        return ResponseEntity.ok(adminService.getStats());
    }
}
