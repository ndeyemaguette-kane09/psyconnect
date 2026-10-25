package com.example.userservice.service;

import com.example.userservice.dto.MedicalHistoryResponse;
import com.example.userservice.dto.UpdateMedicalHistoryRequest;

public interface MedicalHistoryService {

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
