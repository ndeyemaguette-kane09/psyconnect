package com.example.sessionservice.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.sessionservice.dto.SessionResponse;
import com.example.sessionservice.dto.StartEmergencySessionRequest;
import com.example.sessionservice.dto.StartSessionRequest;
import com.example.sessionservice.service.SessionService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/sessions")
public class SessionController {

    private final SessionService sessionService;

    public SessionController(SessionService sessionService) {
        this.sessionService = sessionService;
    }

    /**
     * Démarre une session vidéo pour un RDV.
     * Le premier participant crée la session et obtient le meetingToken (nom de room Jitsi).
     * Le second rejoint via GET /sessions/appointment/{id}.
     */
    @PostMapping("/start")
    public ResponseEntity<SessionResponse> startSession(
            @Valid @RequestBody StartSessionRequest request
    ) {
        return ResponseEntity.ok(sessionService.startSession(request));
    }

    /**
     * Démarre une session d'urgence sans rendez-vous.
     * Utilisé par le bouton SOS du patient pour un appel direct au psy dispo.
     */
    @PostMapping("/emergency")
    public ResponseEntity<SessionResponse> startEmergencySession(
            @Valid @RequestBody StartEmergencySessionRequest request
    ) {
        return ResponseEntity.ok(sessionService.startEmergencySession(request));
    }

    /**
     * Termine une session en cours.
     * Met à jour le statut du RDV dans appointment-service (best-effort).
     */
    @PutMapping("/{id}/end")
    public ResponseEntity<SessionResponse> endSession(@PathVariable Long id) {
        return ResponseEntity.ok(sessionService.endSession(id));
    }

    /** Récupère une session par son ID. */
    @GetMapping("/{id}")
    public ResponseEntity<SessionResponse> getSessionById(@PathVariable Long id) {
        return ResponseEntity.ok(sessionService.getSessionById(id));
    }

    /**
     * Récupère toutes les sessions d'un RDV.
     * Utilisé par le 2e participant pour trouver la session IN_PROGRESS et rejoindre.
     */
    @GetMapping("/appointment/{appointmentId}")
    public ResponseEntity<List<SessionResponse>> getSessionsByAppointment(
            @PathVariable Long appointmentId
    ) {
        return ResponseEntity.ok(sessionService.getSessionsByAppointmentId(appointmentId));
    }
}
