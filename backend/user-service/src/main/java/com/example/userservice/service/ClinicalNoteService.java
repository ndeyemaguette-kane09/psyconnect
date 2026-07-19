package com.example.userservice.service;

import java.util.List;

import com.example.userservice.dto.ClinicalNoteResponse;
import com.example.userservice.dto.CreateOrUpdateClinicalNoteRequest;

// Notes cliniques privées : un seul lecteur/auteur possible, le psychologue
// qui les a rédigées. Jamais le patient, jamais l'admin, jamais un confrère —
// même s'il suit aussi ce patient (cf. CDC section 6)
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
