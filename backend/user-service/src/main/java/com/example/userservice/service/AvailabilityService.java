package com.example.userservice.service;

import com.example.userservice.dto.AvailabilityRequest;
import com.example.userservice.dto.AvailabilityResponse;

import java.util.List;

public interface AvailabilityService {

    // GET public : n'importe qui peut voir les dispos d'un psy
    List<AvailabilityResponse> getAvailabilities(Long psychologistProfileId);

    // PUT propriétaire : remplace toutes les dispos du psy en une transaction
    List<AvailabilityResponse> replaceAvailabilities(
            Long psychologistProfileId,
            List<AvailabilityRequest> requests,
            Long callerAuthUserId
    );
}
