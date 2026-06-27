package com.example.appointmentservice.service;

import java.util.List;

import com.example.appointmentservice.dto.SessionResponse;
import com.example.appointmentservice.dto.StartSessionRequest;

public interface SessionService {

    SessionResponse startSession(StartSessionRequest request);

    SessionResponse endSession(Long id);

    SessionResponse getSessionById(Long id);

    List<SessionResponse> getSessionsByAppointmentId(Long appointmentId);
}
