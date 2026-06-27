package com.example.authservice.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Corps de requête pour PATCH /admin/users/{id}/password : l'admin force un
 * nouveau mot de passe pour un compte (utilisateur qui a perdu l'accès à son
 * email, par exemple). Passé en body plutôt qu'en query string pour éviter
 * qu'un mot de passe en clair ne finisse dans les logs d'accès du gateway.
 */
public class ResetPasswordRequest {

    @NotBlank(message = "Password is required")
    @Size(min = 6, message = "Password must contain at least 6 characters")
    private String newPassword;

    public ResetPasswordRequest() {
    }

    public String getNewPassword() {
        return newPassword;
    }

    public void setNewPassword(String newPassword) {
        this.newPassword = newPassword;
    }
}
