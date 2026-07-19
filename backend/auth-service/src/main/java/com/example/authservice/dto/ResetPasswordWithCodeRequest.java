package com.example.authservice.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

// distinct de ResetPasswordRequest (qui sert au reset force par un ADMIN sur
// /admin/users/{id}/password) : ici c'est le flux self-service "mot de passe
// oublie", verifie par un code recu (cf PasswordResetCode), pas par un JWT admin
public class ResetPasswordWithCodeRequest {

    @NotBlank(message = "L'email est requis")
    @Email(message = "Email invalide")
    private String email;

    @NotBlank(message = "Le code est requis")
    @Size(min = 6, max = 6, message = "Le code doit comporter 6 chiffres")
    private String code;

    @NotBlank(message = "Le nouveau mot de passe est requis")
    @Size(min = 6, message = "Au moins 6 caractères")
    private String newPassword;

    public ResetPasswordWithCodeRequest() {
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getNewPassword() {
        return newPassword;
    }

    public void setNewPassword(String newPassword) {
        this.newPassword = newPassword;
    }
}
