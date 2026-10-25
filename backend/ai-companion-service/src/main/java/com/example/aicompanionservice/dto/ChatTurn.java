package com.example.aicompanionservice.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record ChatTurn(

        @Pattern(regexp = "user|assistant", message = "role doit etre 'user' ou 'assistant'")
        String role,

        @NotBlank
        String content
) {
}
