package com.example.userservice.controller;

import com.example.userservice.dto.MedicalHistoryResponse;
import com.example.userservice.dto.UpdateMedicalHistoryRequest;
import com.example.userservice.service.MedicalHistoryService;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;

// Accessible au patient propriétaire et à un psychologue ayant déjà eu un
// rendez-vous avec ce patient ; jamais à l'admin (vérifié dans le service)
@RestController
@RequestMapping("/patients/{id}/medical-history")
public class MedicalHistoryController {

    private final MedicalHistoryService medicalHistoryService;

    public MedicalHistoryController(MedicalHistoryService medicalHistoryService) {
        this.medicalHistoryService = medicalHistoryService;
    }

    @GetMapping
    public ResponseEntity<MedicalHistoryResponse> getMedicalHistory(
            HttpServletRequest httpRequest,
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(
                medicalHistoryService.getMedicalHistory(
                        id,
                        currentAuthUserId(httpRequest),
                        httpRequest.isUserInRole("PSYCHOLOGIST")
                )
        );
    }

    @PutMapping
    public ResponseEntity<MedicalHistoryResponse> updateMedicalHistory(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @RequestBody UpdateMedicalHistoryRequest request
    ) {
        return ResponseEntity.ok(
                medicalHistoryService.updateMedicalHistory(
                        id,
                        request,
                        currentAuthUserId(httpRequest),
                        httpRequest.isUserInRole("PSYCHOLOGIST")
                )
        );
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
