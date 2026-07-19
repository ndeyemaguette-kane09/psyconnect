package com.example.paymentservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.paymentservice.entity.PlatformSettings;

public interface PlatformSettingsRepository extends JpaRepository<PlatformSettings, Long> {
}
