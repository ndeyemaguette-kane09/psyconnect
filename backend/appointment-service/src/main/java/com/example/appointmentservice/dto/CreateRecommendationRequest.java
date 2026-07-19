package com.example.appointmentservice.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class CreateRecommendationRequest {

    @NotNull(message = "L'identifiant du rendez-vous est obligatoire")
    private Long appointmentId;

    @NotBlank(message = "Le contenu de la recommandation ne peut pas être vide")
    private String content;
}
