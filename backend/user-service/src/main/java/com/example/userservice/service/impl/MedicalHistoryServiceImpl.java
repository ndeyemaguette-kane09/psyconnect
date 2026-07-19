package com.example.userservice.service.impl;

import org.springframework.stereotype.Service;

import com.example.userservice.dto.MedicalHistoryResponse;
import com.example.userservice.dto.UpdateMedicalHistoryRequest;
import com.example.userservice.entity.MedicalHistory;
import com.example.userservice.entity.PatientProfile;
import com.example.userservice.entity.PsychologistProfile;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.MedicalHistoryRepository;
import com.example.userservice.repository.PatientProfileRepository;
import com.example.userservice.repository.PsychologistProfileRepository;
import com.example.userservice.repository.PsyPatientLinkRepository;
import com.example.userservice.service.MedicalHistoryService;

@Service
public class MedicalHistoryServiceImpl implements MedicalHistoryService {

    private final MedicalHistoryRepository medicalHistoryRepository;
    private final PatientProfileRepository patientProfileRepository;
    private final PsychologistProfileRepository psychologistProfileRepository;
    private final PsyPatientLinkRepository psyPatientLinkRepository;

    public MedicalHistoryServiceImpl(
            MedicalHistoryRepository medicalHistoryRepository,
            PatientProfileRepository patientProfileRepository,
            PsychologistProfileRepository psychologistProfileRepository,
            PsyPatientLinkRepository psyPatientLinkRepository
    ) {
        this.medicalHistoryRepository = medicalHistoryRepository;
        this.patientProfileRepository = patientProfileRepository;
        this.psychologistProfileRepository = psychologistProfileRepository;
        this.psyPatientLinkRepository = psyPatientLinkRepository;
    }

    @Override
    public MedicalHistoryResponse getMedicalHistory(
            Long patientId, Long callerAuthUserId, boolean callerIsPsychologist
    ) {

        PatientProfile patientProfile = findPatientProfile(patientId);

        checkAccess(patientProfile, callerAuthUserId, callerIsPsychologist);

        return medicalHistoryRepository.findByPatientProfileId(patientId)
                .map(this::mapToResponse)
                .orElseGet(() -> emptyResponse(patientId));
    }

    @Override
    public MedicalHistoryResponse updateMedicalHistory(
            Long patientId,
            UpdateMedicalHistoryRequest request,
            Long callerAuthUserId,
            boolean callerIsPsychologist
    ) {

        PatientProfile patientProfile = findPatientProfile(patientId);

        boolean isOwner = checkAccess(patientProfile, callerAuthUserId, callerIsPsychologist);

        MedicalHistory medicalHistory = medicalHistoryRepository
                .findByPatientProfileId(patientId)
                .orElseGet(() -> {
                    MedicalHistory created = new MedicalHistory();
                    created.setPatientProfileId(patientId);
                    return created;
                });

        medicalHistory.setAllergies(request.getAllergies());
        medicalHistory.setChronicConditions(request.getChronicConditions());
        medicalHistory.setCurrentTreatments(request.getCurrentTreatments());
        medicalHistory.setPsychiatricHistory(request.getPsychiatricHistory());
        medicalHistory.setLastUpdatedByRole(isOwner ? "PATIENT" : "PSYCHOLOGIST");

        return mapToResponse(medicalHistoryRepository.save(medicalHistory));
    }

    // Renvoie true si l'appelant est le patient propriétaire (utilisé pour
    // tracer qui a fait la dernière modification). Lance ForbiddenOperationException
    // si ni propriétaire, ni psychologue ayant EXPLICITEMENT marqué ce patient comme
    // suivi (PsyPatientLink). Un psychologue avec un RDV passé mais sans lien de suivi
    // actif n'a pas accès aux antécédents.
    private boolean checkAccess(
            PatientProfile patientProfile, Long callerAuthUserId, boolean callerIsPsychologist
    ) {

        boolean isOwner = patientProfile.getAuthUserId() != null
                && patientProfile.getAuthUserId().equals(callerAuthUserId);

        if (isOwner) {
            return true;
        }

        if (callerIsPsychologist) {
            PsychologistProfile psychologistProfile = psychologistProfileRepository
                    .findByAuthUserId(callerAuthUserId)
                    .orElse(null);

            if (psychologistProfile != null
                    && psyPatientLinkRepository.existsByPsychologistProfileIdAndPatientProfileId(
                            psychologistProfile.getId(), patientProfile.getId()
                    )) {
                return false;
            }
        }

        throw new ForbiddenOperationException(
                "Vous n'avez pas accès aux antécédents médicaux de ce patient"
        );
    }

    private PatientProfile findPatientProfile(Long patientId) {
        return patientProfileRepository.findById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Patient profile not found"
                ));
    }

    private MedicalHistoryResponse emptyResponse(Long patientId) {
        MedicalHistoryResponse response = new MedicalHistoryResponse();
        response.setPatientId(patientId);
        return response;
    }

    private MedicalHistoryResponse mapToResponse(MedicalHistory medicalHistory) {
        MedicalHistoryResponse response = new MedicalHistoryResponse();
        response.setPatientId(medicalHistory.getPatientProfileId());
        response.setAllergies(medicalHistory.getAllergies());
        response.setChronicConditions(medicalHistory.getChronicConditions());
        response.setCurrentTreatments(medicalHistory.getCurrentTreatments());
        response.setPsychiatricHistory(medicalHistory.getPsychiatricHistory());
        response.setUpdatedAt(medicalHistory.getUpdatedAt());
        response.setLastUpdatedByRole(medicalHistory.getLastUpdatedByRole());
        return response;
    }
}
