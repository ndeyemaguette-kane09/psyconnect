package com.example.appointmentservice.dto;

import lombok.Getter;
import lombok.Setter;
import jakarta.validation.constraints.NotNull;

@Getter
@Setter
public class StartConversationRequest {

    /**
     * Id du profil de l'AUTRE participant : un PsychologistProfile.id si
     * l'appelant est patient, un PatientProfile.id si l'appelant est
     * psychologue (résolu côté service selon le rôle de l'appelant).
     */
    @NotNull(message = "L'identifiant de l'autre participant est requis")
    private Long otherProfileId;
}
