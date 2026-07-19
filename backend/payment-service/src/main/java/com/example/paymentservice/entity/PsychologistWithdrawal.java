package com.example.paymentservice.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

// retrait simulé du revenu net d'un psychologue. en mode simulation
// le statut est toujours COMPLETED : on enregistre le mouvement sans
// déclencher de vrai virement. La somme disponible = totalNetRevenue
// (calculé dynamiquement depuis les paiements) - totalWithdrawn (somme
// des retraits de cette table).
@Entity
@Table(name = "psychologist_withdrawals")
@Getter
@Setter
public class PsychologistWithdrawal {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long psychologistId;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    // ORANGE_MONEY | WAVE | BANK_TRANSFER (simulés)
    @Column(nullable = false)
    private String method;

    @Column(nullable = false)
    private String status;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        if (this.status == null) this.status = "COMPLETED";
    }

    public PsychologistWithdrawal() {}
}
