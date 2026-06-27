package com.example.userservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * Une ligne du relevé du solde d'un patient : le mouvement et le solde
 * résultant. Immutable une fois écrite.
 */
@Entity
@Table(name = "wallet_transactions")
@Getter
@Setter
public class WalletTransaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "patient_profile_id", nullable = false)
    private PatientProfile patientProfile;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private WalletTransactionType type;

    @Column(nullable = false)
    private Double amount;

    // Solde juste après ce mouvement, stocké en dur (pas recalculé) pour
    // rester exact même si d'autres mouvements arrivent entre deux lectures.
    @Column(nullable = false)
    private Double balanceAfter;

    // Moyen mobile money pour un dépôt/retrait, null pour un débit/crédit
    // (pas de mouvement réel d'argent dans ce cas).
    private String method;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    public WalletTransaction() {
    }
}
