package com.example.sessionservice.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.sessionservice.dto.AdminEmergencySessionResponse;
import com.example.sessionservice.service.SessionService;

@RestController
@RequestMapping("/admin/emergency-sessions")
public class AdminEmergencySessionController {

    private final SessionService sessionService;

    public AdminEmergencySessionController(SessionService sessionService) {
        this.sessionService = sessionService;
    }

    @GetMapping
    public ResponseEntity<List<AdminEmergencySessionResponse>> listEmergencySessions() {
        return ResponseEntity.ok(sessionService.listEmergencySessionsForAdmin());
    }
}
