package com.example.sessionservice.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.sessionservice.entity.Session;
import com.example.sessionservice.entity.SessionStatus;

public interface SessionRepository extends JpaRepository<Session, Long> {

    List<Session> findByAppointmentId(Long appointmentId);

    boolean existsByAppointmentIdAndStatus(Long appointmentId, SessionStatus status);
}
