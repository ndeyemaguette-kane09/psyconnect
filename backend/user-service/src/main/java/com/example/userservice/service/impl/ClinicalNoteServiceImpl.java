package com.example.userservice.service.impl;

import java.util.List;

import org.springframework.stereotype.Service;

import com.example.userservice.dto.ClinicalNoteResponse;
import com.example.userservice.dto.CreateOrUpdateClinicalNoteRequest;
import com.example.userservice.entity.ClinicalNote;
import com.example.userservice.entity.PsychologistProfile;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.ClinicalNoteRepository;
import com.example.userservice.repository.PatientProfileRepository;
import com.example.userservice.repository.PsychologistProfileRepository;
import com.example.userservice.repository.PsyPatientLinkRepository;
import com.example.userservice.service.ClinicalNoteService;

// La vérification de suivi utilise maintenant PsyPatientLinkRepository (table locale)
// au lieu d'AppointmentClient. Avantages :
// - plus de dépendance réseau vers appointment-service pour chaque accès aux notes
// - plus de faux "Vous ne suivez pas ce patient" si le circuit-breaker s'ouvre
// - relation explicite : le psy doit avoir activement marqué le patient comme "suivi"
@Service
public class ClinicalNoteServiceImpl implements ClinicalNoteService {

    private final ClinicalNoteRepository clinicalNoteRepository;
    private final PatientProfileRepository patientProfileRepository;
    private final PsychologistProfileRepository psychologistProfileRepository;
    private final PsyPatientLinkRepository psyPatientLinkRepository;

    public ClinicalNoteServiceImpl(
            ClinicalNoteRepository clinicalNoteRepository,
            PatientProfileRepository patientProfileRepository,
            PsychologistProfileRepository psychologistProfileRepository,
            PsyPatientLinkRepository psyPatientLinkRepository
    ) {
        this.clinicalNoteRepository = clinicalNoteRepository;
        this.patientProfileRepository = patientProfileRepository;
        this.psychologistProfileRepository = psychologistProfileRepository;
        this.psyPatientLinkRepository = psyPatientLinkRepository;
    }

    @Override
    public List<ClinicalNoteResponse> getMyNotesForPatient(Long patientId, Long callerAuthUserId) {

        PsychologistProfile psychologistProfile = currentPsychologistProfile(callerAuthUserId);
        ensureFollowsPatient(psychologistProfile, patientId);

        return clinicalNoteRepository
                .findByPatientProfileIdAndPsychologistProfileIdOrderByCreatedAtDesc(
                        patientId, psychologistProfile.getId()
                )
                .stream()
                .map(this::mapToResponse)
                .toList();
    }

    @Override
    public ClinicalNoteResponse createNote(
            Long patientId, CreateOrUpdateClinicalNoteRequest request, Long callerAuthUserId
    ) {

        if (request.getContent() == null || request.getContent().isBlank()) {
            throw new IllegalArgumentException("Le contenu de la note ne peut pas être vide");
        }

        PsychologistProfile psychologistProfile = currentPsychologistProfile(callerAuthUserId);
        ensureFollowsPatient(psychologistProfile, patientId);

        ClinicalNote note = new ClinicalNote();
        note.setPatientProfileId(patientId);
        note.setPsychologistProfileId(psychologistProfile.getId());
        note.setAppointmentId(request.getAppointmentId());
        note.setContent(request.getContent());

        return mapToResponse(clinicalNoteRepository.save(note));
    }

    @Override
    public ClinicalNoteResponse updateNote(
            Long noteId, CreateOrUpdateClinicalNoteRequest request, Long callerAuthUserId
    ) {

        if (request.getContent() == null || request.getContent().isBlank()) {
            throw new IllegalArgumentException("Le contenu de la note ne peut pas être vide");
        }

        PsychologistProfile psychologistProfile = currentPsychologistProfile(callerAuthUserId);
        ClinicalNote note = findOwnNote(noteId, psychologistProfile.getId());

        note.setContent(request.getContent());
        note.setAppointmentId(request.getAppointmentId());

        return mapToResponse(clinicalNoteRepository.save(note));
    }

    @Override
    public void deleteNote(Long noteId, Long callerAuthUserId) {

        PsychologistProfile psychologistProfile = currentPsychologistProfile(callerAuthUserId);
        ClinicalNote note = findOwnNote(noteId, psychologistProfile.getId());

        clinicalNoteRepository.delete(note);
    }

    private PsychologistProfile currentPsychologistProfile(Long callerAuthUserId) {
        return psychologistProfileRepository
                .findByAuthUserId(callerAuthUserId)
                .orElseThrow(() -> new ForbiddenOperationException(
                        "Seul un psychologue peut accéder aux notes cliniques"
                ));
    }

    // vérifie que le psy a explicitement marqué ce patient comme "suivi".
    // remplace l'ancien check appointmentClient.hasAppointmentBetween() qui
    // dépendait de la disponibilité d'appointment-service.
    private void ensureFollowsPatient(PsychologistProfile psychologistProfile, Long patientId) {

        if (!patientProfileRepository.existsById(patientId)) {
            throw new ResourceNotFoundException("Patient profile not found");
        }

        if (!psyPatientLinkRepository.existsByPsychologistProfileIdAndPatientProfileId(
                psychologistProfile.getId(), patientId)) {
            throw new ForbiddenOperationException(
                    "Ce patient ne fait pas partie de vos patients suivis. "
                    + "Ajoutez-le depuis la fiche patient pour accéder aux notes cliniques."
            );
        }
    }

    private ClinicalNote findOwnNote(Long noteId, Long psychologistProfileId) {
        return clinicalNoteRepository
                .findByIdAndPsychologistProfileId(noteId, psychologistProfileId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Note clinique introuvable"
                ));
    }

    private ClinicalNoteResponse mapToResponse(ClinicalNote note) {
        ClinicalNoteResponse response = new ClinicalNoteResponse();
        response.setId(note.getId());
        response.setPatientProfileId(note.getPatientProfileId());
        response.setAppointmentId(note.getAppointmentId());
        response.setContent(note.getContent());
        response.setCreatedAt(note.getCreatedAt());
        response.setUpdatedAt(note.getUpdatedAt());
        return response;
    }
}
