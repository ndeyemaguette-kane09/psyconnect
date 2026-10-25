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

    @PostMapping("/start")
    public ResponseEntity<SessionResponse> startSession(
            @Valid @RequestBody StartSessionRequest request
    ) {
        return ResponseEntity.ok(sessionService.startSession(request));
    }

    @PostMapping("/emergency")
    public ResponseEntity<SessionResponse> startEmergencySession(
            @Valid @RequestBody StartEmergencySessionRequest request
    ) {
        return ResponseEntity.ok(sessionService.startEmergencySession(request));
    }

    @PutMapping("/{id}/end")
    public ResponseEntity<SessionResponse> endSession(@PathVariable Long id) {
        return ResponseEntity.ok(sessionService.endSession(id));
    }

    /** Récupère une session par son ID. */
    @GetMapping("/{id}")
    public ResponseEntity<SessionResponse> getSessionById(@PathVariable Long id) {
        return ResponseEntity.ok(sessionService.getSessionById(id));
    }

    @GetMapping("/appointment/{appointmentId}")
    public ResponseEntity<List<SessionResponse>> getSessionsByAppointment(
            @PathVariable Long appointmentId
    ) {
        return ResponseEntity.ok(sessionService.getSessionsByAppointmentId(appointmentId));
    }
}
