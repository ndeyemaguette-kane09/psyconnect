package com.example.paymentservice.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;
import lombok.Setter;

// une ligne de l'historique détaillé des paiements reçus par un psy :
// 1 RDV = 1 entrée, avec montant brut/net et identifiant du patient.
// le pseudo du patient est résolu côté Flutter (GET /patients/{id})
// pour éviter un appel supplémentaire user-service depuis payment-service.
@Getter
@Setter
public class PaymentTransactionDto {

    private Long paymentId;
    private Long appointmentId;

    // patientId = PatientProfile.id, pas authUserId
    // utilisé par Flutter pour charger le profil patient et afficher son pseudo
    private Long patientId;

    // date/heure du RDV (pas du paiement) pour la traçabilité
    // @JsonFormat : évite les nanosecondes (9 chiffres) que Dart ne parse pas
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime appointmentStartTime;

    private BigDecimal grossAmount;      // montant brut payé par le patient
    private BigDecimal netAmount;        // après déduction de la commission plateforme
    private BigDecimal commissionAmount; // = grossAmount - netAmount

    // COMPLETED (paiement reçu) ou REFUNDED (RDV annulé, remboursé au patient)
    private String status;

    private String transactionReference;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime paidAt;        // = createdAt du paiement
}
