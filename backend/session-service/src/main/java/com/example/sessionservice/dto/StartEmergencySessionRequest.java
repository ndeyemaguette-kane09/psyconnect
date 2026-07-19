package com.example.sessionservice.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

// démarrer une session d'urgence sans rendez-vous préalable.
// patientId et psychologistId sont les IDs des profils (pas authUserId).
@Getter
@Setter
public class StartEmergencySessionRequest {

    @NotNull(message = "L'identifiant du profil patient est obligatoire")
    private Long patientId;

    @NotNull(message = "L'identifiant du profil psychologue est obligatoire")
    private Long psychologistId;
}
