package com.example.userservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.userservice.entity.PsychologistProfile;

public interface PsychologistProfileRepository extends JpaRepository<PsychologistProfile, Long> {

    java.util.Optional<PsychologistProfile> findByAuthUserId(Long authUserId);

    long countByProfileVerified(Boolean profileVerified);

    long countByRejected(Boolean rejected);

    long countByProfileVerifiedAndRejected(Boolean profileVerified, Boolean rejected);
}
