package com.example.userservice.controller;

import com.example.userservice.service.PsyPatientLinkService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// gestion du lien de suivi psychologue ↔ patient.
// routes sous /psychologists/{psyId}/followed-patients/**
//
// POST   /psychologists/{psyId}/followed-patients/{patientId}  → ajouter au suivi
// DELETE /psychologists/{psyId}/followed-patients/{patientId}  → retirer du suivi
// GET    /psychologists/{psyId}/followed-patients              → liste patientIds suivis
// GET    /psychologists/{psyId}/followed-patients/{patientId}  → true/false
@RestController
@RequestMapping("/psychologists")
public class PsyPatientLinkController {

    private final PsyPatientLinkService service;

    public PsyPatientLinkController(PsyPatientLinkService service) {
        this.service = service;
    }

    @PostMapping("/{psyId}/followed-patients/{patientId}")
    public ResponseEntity<Void> addFollowedPatient(
            @PathVariable Long psyId,
            @PathVariable Long patientId,
            HttpServletRequest request
    ) {
        service.addFollowedPatient(psyId, patientId, currentAuthUserId(request));
        return ResponseEntity.status(HttpStatus.CREATED).build();
    }

    @DeleteMapping("/{psyId}/followed-patients/{patientId}")
    public ResponseEntity<Void> removeFollowedPatient(
            @PathVariable Long psyId,
            @PathVariable Long patientId,
            HttpServletRequest request
    ) {
        service.removeFollowedPatient(psyId, patientId, currentAuthUserId(request));
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{psyId}/followed-patients")
    public ResponseEntity<List<Long>> getFollowedPatients(
            @PathVariable Long psyId,
            HttpServletRequest request
    ) {
        return ResponseEntity.ok(
                service.getFollowedPatientIds(psyId, currentAuthUserId(request))
        );
    }

    // vérification stateless : pas besoin d'authentification pour juste savoir
    // si un lien existe (utilisé par Flutter pour initialiser l'état du toggle)
    @GetMapping("/{psyId}/followed-patients/{patientId}")
    public ResponseEntity<Boolean> isFollowing(
            @PathVariable Long psyId,
            @PathVariable Long patientId
    ) {
        return ResponseEntity.ok(service.isFollowing(psyId, patientId));
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
