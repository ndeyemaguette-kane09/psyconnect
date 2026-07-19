package com.example.userservice.repository;

import com.example.userservice.entity.PsyPatientLink;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface PsyPatientLinkRepository extends JpaRepository<PsyPatientLink, Long> {

    // vérification rapide : ce psy suit-il ce patient ?
    boolean existsByPsychologistProfileIdAndPatientProfileId(
            Long psychologistProfileId, Long patientProfileId);

    // suppression du lien (le psy retire le patient de son suivi)
    @Modifying
    @Transactional
    void deleteByPsychologistProfileIdAndPatientProfileId(
            Long psychologistProfileId, Long patientProfileId);

    // liste des patientProfileId suivis par ce psy
    @Query("SELECT l.patientProfileId FROM PsyPatientLink l WHERE l.psychologistProfileId = :psyId")
    List<Long> findPatientIdsByPsychologistProfileId(@Param("psyId") Long psyId);
}
