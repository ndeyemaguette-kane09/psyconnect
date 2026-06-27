package com.example.appointmentservice.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.appointmentservice.entity.Conversation;

public interface ConversationRepository extends JpaRepository<Conversation, Long> {

    Optional<Conversation> findByPatientIdAndPsychologistId(Long patientId, Long psychologistId);

    List<Conversation> findByPatientIdOrderByLastMessageAtDesc(Long patientId);

    List<Conversation> findByPsychologistIdOrderByLastMessageAtDesc(Long psychologistId);
}
