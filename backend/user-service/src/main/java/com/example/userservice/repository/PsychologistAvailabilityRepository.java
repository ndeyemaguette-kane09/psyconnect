package com.example.userservice.repository;

import com.example.userservice.entity.PsychologistAvailability;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PsychologistAvailabilityRepository
        extends JpaRepository<PsychologistAvailability, Long> {

    List<PsychologistAvailability> findByPsychologistProfileIdOrderByDayOfWeekAscStartHourAsc(
            Long psychologistProfileId);

    // pour le PUT "remplace tout" : on supprime d'abord toutes les dispos du psy
    void deleteByPsychologistProfileId(Long psychologistProfileId);

    Optional<PsychologistAvailability> findByIdAndPsychologistProfileId(
            Long id, Long psychologistProfileId);
}
