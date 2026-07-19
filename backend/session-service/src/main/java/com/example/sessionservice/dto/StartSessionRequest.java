package com.example.sessionservice.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class StartSessionRequest {

    @NotNull(message = "L'identifiant du rendez-vous est obligatoire")
    private Long appointmentId;
}
