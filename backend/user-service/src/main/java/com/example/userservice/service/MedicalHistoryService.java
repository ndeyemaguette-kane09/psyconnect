package com.example.userservice.service;

import com.example.userservice.dto.MedicalHistoryResponse;
import com.example.userservice.dto.UpdateMedicalHistoryRequest;

public interface MedicalHistoryService {

    /**
     * Acces accorde si l'appelant est le patient proprietaire, ou un
     * psychologue ayant deja eu un rendez-vous avec ce patient. Jamais
     * accessible a l'admin (ni a un psy "etranger" a ce patient).
     *
     * @param callerIsPsychologist true si l'appelant a le role PSYCHOLOGIST
     */
    MedicalHistoryResponse getMedicalHistory(
            Long patientId,
            Long callerAuthUserId,
            boolean callerIsPsychologist
    );

    MedicalHistoryResponse updateMedicalHistory(
            Long patientId,
            UpdateMedicalHistoryRequest request,
            Long callerAuthUserId,
            boolean callerIsPsychologist
    );
}
