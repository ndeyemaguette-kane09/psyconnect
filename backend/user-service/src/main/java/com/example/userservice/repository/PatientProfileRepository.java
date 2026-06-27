package com.example.userservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.userservice.entity.PatientProfile;


public interface PatientProfileRepository extends JpaRepository<PatientProfile, Long> {

    java.util.Optional<PatientProfile> findByAuthUserId(Long authUserId);
}
