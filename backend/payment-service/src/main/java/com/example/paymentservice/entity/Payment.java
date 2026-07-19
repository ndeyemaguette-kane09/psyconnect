package com.example.paymentservice.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "payments")
@Getter
@Setter
public class Payment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long appointmentId;

    @Column(nullable = false)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentMethod method;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentStatus status;

    @Column(nullable = false, unique = true)
    private String transactionReference;

    // dupliqués depuis AppointmentSummary au moment du paiement pour éviter
    // d'appeler appointment-service lors du calcul du revenu/wallet/transactions
    @Column
    private Long psychologistId;

    @Column
    private Long patientId;

    @Column
    private LocalDateTime appointmentStartTime;

    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    public Payment() {
    }
}
