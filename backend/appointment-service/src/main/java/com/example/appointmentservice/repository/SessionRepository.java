package com.example.appointmentservice.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.appointmentservice.entity.Session;
import com.example.appointmentservice.entity.SessionStatus;

public interface SessionRepository
        extends JpaRepository<Session, Long> {

    List<Session> findByAppointmentId(Long appointmentId);

    boolean existsByAppointmentIdAndStatus(
            Long appointmentId,
            SessionStatus status
    );
}
