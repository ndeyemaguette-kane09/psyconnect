package com.example.userservice.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.userservice.entity.ClinicalNote;

public interface ClinicalNoteRepository extends JpaRepository<ClinicalNote, Long> {

    // toujours filtre par psychologistProfileId : un psy ne doit jamais
    // recevoir les notes d'un confrère sur le même patient
    List<ClinicalNote> findByPatientProfileIdAndPsychologistProfileIdOrderByCreatedAtDesc(
            Long patientProfileId, Long psychologistProfileId
    );

    Optional<ClinicalNote> findByIdAndPsychologistProfileId(Long id, Long psychologistProfileId);
}
