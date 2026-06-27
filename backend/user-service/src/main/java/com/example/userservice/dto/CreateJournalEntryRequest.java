package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;
import jakarta.validation.constraints.NotBlank;

@Getter
@Setter
public class CreateJournalEntryRequest {

    @NotBlank(message = "Le contenu du journal ne peut pas être vide")
    private String content;

    private Integer moodRating;
}
