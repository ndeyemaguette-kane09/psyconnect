package com.example.appointmentservice.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.appointmentservice.dto.SessionResponse;
import com.example.appointmentservice.dto.StartSessionRequest;
import com.example.appointmentservice.service.SessionService;

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
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(sessionService.startSession(request));
    }

    @PostMapping("/{id}/end")
    public ResponseEntity<SessionResponse> endSession(
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(sessionService.endSession(id));
    }

    @GetMapping("/{id}")
    public ResponseEntity<SessionResponse> getSessionById(
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(sessionService.getSessionById(id));
    }

    @GetMapping("/appointment/{appointmentId}")
    public ResponseEntity<List<SessionResponse>> getSessionsByAppointmentId(
            @PathVariable Long appointmentId
    ) {
        return ResponseEntity.ok(
                sessionService.getSessionsByAppointmentId(appointmentId)
        );
    }
}
