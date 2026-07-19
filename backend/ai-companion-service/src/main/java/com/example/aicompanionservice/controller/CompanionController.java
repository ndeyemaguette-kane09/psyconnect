package com.example.aicompanionservice.controller;

import com.example.aicompanionservice.dto.ChatRequest;
import com.example.aicompanionservice.dto.ChatResponse;
import com.example.aicompanionservice.service.CompanionService;

import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * IMPORTANT (confidentialité) : ce contrôleur ne journalise jamais le
 * contenu de "request" ni de la réponse. N'ajoutez pas de
 * log.info(request)/log.debug(...) sur ces objets : le contenu des
 * échanges entre l'utilisateur et le compagnon IA doit rester confidentiel
 * (ni visible par un psychologue, ni par un admin, ni dans les logs).
 * Seules les métadonnées de traçage (timing, statut HTTP) sont exportées
 * vers Zipkin, jamais le corps de la requête.
 */
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
