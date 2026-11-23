package com.example.paymentservice.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

// outbox des mouvements de portefeuille, rejoués jusqu'à confirmation de user-service
@Entity
@Table(name = "wallet_operations")
@Getter
@Setter
public class WalletOperation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String operationKey;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private WalletOperationType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private WalletOperationStatus status;

    @Column(nullable = false)
    private Long patientId;

    private BigDecimal amount;

    private Long paymentId;

    // pour REVERSE_DEBIT : clé du débit à annuler
    private String targetOperationKey;

    private int attempts;

    @Column(length = 500)
    private String lastError;

    @Column(nullable = false)
    private LocalDateTime nextAttemptAt;

    private LocalDateTime createdAt;

    private LocalDateTime doneAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    public WalletOperation() {
    }
}
