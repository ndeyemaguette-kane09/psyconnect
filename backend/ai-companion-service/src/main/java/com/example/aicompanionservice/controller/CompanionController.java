package com.example.aicompanionservice.controller;

import com.example.aicompanionservice.dto.ChatRequest;
import com.example.aicompanionservice.dto.ChatResponse;
import com.example.aicompanionservice.service.CompanionService;

import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

// confidentialité : on ne journalise jamais le contenu des messages
@RestController
public class CompanionController {

    private final CompanionService companionService;

    public CompanionController(CompanionService companionService) {
        this.companionService = companionService;
    }

    @PostMapping("/companion/chat")
    public ChatResponse chat(@Valid @RequestBody ChatRequest request) {
        return companionService.respond(request);
    }
}
