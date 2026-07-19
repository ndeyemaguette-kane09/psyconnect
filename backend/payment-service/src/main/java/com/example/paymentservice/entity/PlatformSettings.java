package com.example.paymentservice.entity;

import java.math.BigDecimal;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

// reglages plateforme, une seule ligne en base
@Entity
@Table(name = "platform_settings")
@Getter
@Setter
public class PlatformSettings {

    @Id
    private Long id;

    // pourcentage (0-100) prelevé par la plateforme sur chaque paiement
    @Column(nullable = false)
    private BigDecimal commissionRatePercent = new BigDecimal("20");

    public PlatformSettings() {
    }
}
