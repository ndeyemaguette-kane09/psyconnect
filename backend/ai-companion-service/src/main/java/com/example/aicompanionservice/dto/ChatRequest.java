package com.example.aicompanionservice.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

public record ChatRequest(

        @NotBlank
        @Size(max = 4000)
        String message,

        @Valid
        List<ChatTurn> history
) {

    public List<ChatTurn> historyOrEmpty() {
        return history == null ? List.of() : history;
    }
}
