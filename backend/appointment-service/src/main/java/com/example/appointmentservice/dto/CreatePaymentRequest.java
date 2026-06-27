package com.example.appointmentservice.dto;

import java.math.BigDecimal;

import com.example.appointmentservice.entity.PaymentMethod;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class CreatePaymentRequest {

    @NotNull(message = "L'identifiant du rendez-vous est obligatoire")
    private Long appointmentId;

    @NotNull(message = "Le montant est obligatoire")
    @DecimalMin(value = "0.0", inclusive = false, message = "Le montant doit être supérieur à zéro")
    private BigDecimal amount;

    // Conservé pour compatibilité mais ignoré par PaymentServiceImpl
    // #createPayment : tout paiement est forcé à PaymentMethod.WALLET, le
    // choix du moyen de paiement se fait en amont à la recharge du solde.
    private PaymentMethod method;
}
