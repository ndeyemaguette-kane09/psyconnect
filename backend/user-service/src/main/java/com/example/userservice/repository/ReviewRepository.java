package com.example.userservice.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.userservice.entity.Review;

public interface ReviewRepository extends JpaRepository<Review, Long> {

    Optional<Review> findByPatientProfileIdAndPsychologistProfileId(
            Long patientProfileId, Long psychologistProfileId
    );

    List<Review> findByPsychologistProfileIdOrderByUpdatedAtDesc(Long psychologistProfileId);
}
