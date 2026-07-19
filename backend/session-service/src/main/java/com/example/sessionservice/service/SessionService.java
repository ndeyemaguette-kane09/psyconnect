package com.example.sessionservice.service;

import java.util.List;

import com.example.sessionservice.dto.SessionResponse;
import com.example.sessionservice.dto.StartEmergencySessionRequest;
import com.example.sessionservice.dto.StartSessionRequest;

public interface SessionService {
    SessionResponse startSession(StartSessionRequest request);
    // session d'urgence : pas de RDV, appel direct psy ↔ patient
    SessionResponse startEmergencySession(StartEmergencySessionRequest request);
    SessionResponse endSession(Long id);
    SessionResponse getSessionById(Long id);
    List<SessionResponse> getSessionsByAppointmentId(Long appointmentId);
}
