package com.example.appointmentservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.appointmentservice.entity.PlatformSettings;

public interface PlatformSettingsRepository extends JpaRepository<PlatformSettings, Long> {
}
