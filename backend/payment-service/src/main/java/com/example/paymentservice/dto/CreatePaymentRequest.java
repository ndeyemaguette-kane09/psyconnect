package com.example.paymentservice.dto;

import java.math.BigDecimal;

import com.example.paymentservice.entity.PaymentMethod;

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

    // ignoré, tout paiement passe par le wallet maintenant
    private PaymentMethod method;
}
