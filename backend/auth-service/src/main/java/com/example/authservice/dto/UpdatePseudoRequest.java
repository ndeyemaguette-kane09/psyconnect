package com.example.authservice.dto;

import jakarta.validation.constraints.NotBlank;

public class UpdatePseudoRequest {

    @NotBlank(message = "Pseudo is required")
    private String pseudo;

    public String getPseudo() {
        return pseudo;
    }

    public void setPseudo(String pseudo) {
        this.pseudo = pseudo;
    }
}
