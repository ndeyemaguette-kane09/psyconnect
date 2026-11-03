package com.example.userservice.service;

import java.util.List;

import com.example.userservice.dto.ClinicalNoteResponse;
import com.example.userservice.dto.CreateOrUpdateClinicalNoteRequest;

// notes privées : seul le psy auteur y a accès, ni le patient, ni l'admin, ni un confrère
public interface ClinicalNoteService {

    List<ClinicalNoteResponse> getMyNotesForPatient(Long patientId, Long callerAuthUserId);

    ClinicalNoteResponse createNote(
            Long patientId, CreateOrUpdateClinicalNoteRequest request, Long callerAuthUserId
    );

    ClinicalNoteResponse updateNote(
            Long noteId, CreateOrUpdateClinicalNoteRequest request, Long callerAuthUserId
    );

    void deleteNote(Long noteId, Long callerAuthUserId);
}
