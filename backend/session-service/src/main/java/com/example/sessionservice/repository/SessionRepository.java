package com.example.sessionservice.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.sessionservice.entity.Session;
import com.example.sessionservice.entity.SessionStatus;

public interface SessionRepository extends JpaRepository<Session, Long> {

    List<Session> findByAppointmentId(Long appointmentId);

    Optional<Session> findFirstByAppointmentIdAndStatus(Long appointmentId, SessionStatus status);

    boolean existsByAppointmentIdAndStatus(Long appointmentId, SessionStatus status);
List<Session> findByStatusAndAppointmentIdIsNotNull(SessionStatus status);
}
