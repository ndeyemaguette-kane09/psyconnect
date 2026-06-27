package com.example.appointmentservice.dto;

import lombok.Getter;
import lombok.Setter;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@Getter
@Setter
public class SendMessageRequest {

    @NotBlank(message = "Le message ne peut pas être vide")
    @Size(max = 2000, message = "Message trop long (max 2000 caractères)")
    private String content;
}
