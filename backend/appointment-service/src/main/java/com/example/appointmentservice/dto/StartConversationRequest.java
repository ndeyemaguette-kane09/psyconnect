package com.example.appointmentservice.dto;

import lombok.Getter;
import lombok.Setter;
import jakarta.validation.constraints.NotNull;

@Getter
@Setter
public class StartConversationRequest {

    // id de l'autre personne dans la conversation
    @NotNull(message = "L'identifiant de l'autre participant est requis")
    private Long otherProfileId;
}
