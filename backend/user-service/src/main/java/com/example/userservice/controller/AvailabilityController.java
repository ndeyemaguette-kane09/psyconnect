package com.example.userservice.controller;

import com.example.userservice.dto.AvailabilityResponse;
import com.example.userservice.dto.ReplaceAvailabilitiesRequest;
import com.example.userservice.service.AvailabilityService;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// disponibilites hebdomadaires d'un psychologue
//   GET  /psychologists/{id}/availabilities  : public (pas de token requis)
//   PUT  /psychologists/{id}/availabilities  : proprietaire du profil seulement
//
// La route est déjà couverte par la gateway via spring.cloud.gateway.routes[5]
// (Path=/psychologists/**), pas besoin d'ajout dans application.properties
@RestController
@RequestMapping("/psychologists/{id}/availabilities")
public class AvailabilityController {

    private final AvailabilityService availabilityService;

    public AvailabilityController(AvailabilityService availabilityService) {
        this.availabilityService = availabilityService;
    }

    // liste publique des plages de disponibilite d'un psy
    // (pas de controle d'acces : un patient non connecte peut consulter)
    @GetMapping
    public ResponseEntity<List<AvailabilityResponse>> getAvailabilities(
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(availabilityService.getAvailabilities(id));
    }

    // remplacement complet : le psy envoie toute sa semaine en une fois.
    // une liste vide efface toutes les dispos (psy "indisponible").
    @PutMapping
    public ResponseEntity<List<AvailabilityResponse>> replaceAvailabilities(
            @PathVariable Long id,
            @RequestBody @Valid ReplaceAvailabilitiesRequest request,
            HttpServletRequest httpRequest
    ) {
        return ResponseEntity.ok(
                availabilityService.replaceAvailabilities(
                        id,
                        request.getAvailabilities(),
                        currentAuthUserId(httpRequest)
                )
        );
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
