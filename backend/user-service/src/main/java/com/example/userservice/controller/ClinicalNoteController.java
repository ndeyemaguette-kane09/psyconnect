package com.example.userservice.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.userservice.dto.ClinicalNoteResponse;
import com.example.userservice.dto.CreateOrUpdateClinicalNoteRequest;
import com.example.userservice.service.ClinicalNoteService;

import jakarta.servlet.http.HttpServletRequest;

// Notes cliniques privées du psychologue : jamais d'endpoint côté patient ni
// admin ici, et le service refuse l'accès à un psychologue "étranger" au patient
// (cf. ClinicalNoteServiceImpl) — voir CDC section 6 "jamais visibles par
// des tiers non autorisés"
@RestController
public class ClinicalNoteController {

    private final ClinicalNoteService clinicalNoteService;

    public ClinicalNoteController(ClinicalNoteService clinicalNoteService) {
        this.clinicalNoteService = clinicalNoteService;
    }

    @GetMapping("/patients/{id}/clinical-notes")
    public ResponseEntity<List<ClinicalNoteResponse>> getMyNotesForPatient(
            HttpServletRequest httpRequest,
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(
                clinicalNoteService.getMyNotesForPatient(id, currentAuthUserId(httpRequest))
        );
    }

    @PostMapping("/patients/{id}/clinical-notes")
    public ResponseEntity<ClinicalNoteResponse> createNote(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @RequestBody CreateOrUpdateClinicalNoteRequest request
    ) {
        return ResponseEntity.ok(
                clinicalNoteService.createNote(id, request, currentAuthUserId(httpRequest))
        );
    }

    @PutMapping("/clinical-notes/{noteId}")
    public ResponseEntity<ClinicalNoteResponse> updateNote(
            HttpServletRequest httpRequest,
            @PathVariable Long noteId,
            @RequestBody CreateOrUpdateClinicalNoteRequest request
    ) {
        return ResponseEntity.ok(
                clinicalNoteService.updateNote(noteId, request, currentAuthUserId(httpRequest))
        );
    }

    @DeleteMapping("/clinical-notes/{noteId}")
    public ResponseEntity<Void> deleteNote(
            HttpServletRequest httpRequest,
            @PathVariable Long noteId
    ) {
        clinicalNoteService.deleteNote(noteId, currentAuthUserId(httpRequest));
        return ResponseEntity.noContent().build();
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
