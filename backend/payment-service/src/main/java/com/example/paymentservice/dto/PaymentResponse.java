package com.example.paymentservice.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.example.paymentservice.entity.PaymentMethod;
import com.example.paymentservice.entity.PaymentStatus;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class PaymentResponse {

    private Long id;
    private Long appointmentId;
    private BigDecimal amount;
    private PaymentMethod method;
    private PaymentStatus status;
    private String transactionReference;
    private LocalDateTime createdAt;
}
