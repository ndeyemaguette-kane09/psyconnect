package com.example.appointmentservice.entity;

import java.math.BigDecimal;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * Réglages globaux de la plateforme. Une seule ligne en base (id fixe = 1),
 * créée à la volée avec des valeurs par défaut si elle n'existe pas encore
 * (cf. AdminController#getOrCreateSettings). Pour l'instant ne contient que
 * la commission prélevée par l'administrateur sur chaque paiement réussi —
 * demande explicite de l'admin de pouvoir "préciser" sa part de revenus
 * plutôt que de n'afficher que le revenu brut total.
 */
@Entity
@Table(name = "platform_settings")
@Getter
@Setter
public class PlatformSettings {

    @Id
    private Long id;

    /** Pourcentage (0 à 100) prélevé par la plateforme sur chaque paiement réussi. */
    @Column(nullable = false)
    private BigDecimal commissionRatePercent = new BigDecimal("20");

    public PlatformSettings() {
    }
}
