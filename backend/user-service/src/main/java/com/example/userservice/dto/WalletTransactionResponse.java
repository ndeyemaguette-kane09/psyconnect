package com.example.userservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

// une ligne du relevé (GET /patients/{id}/wallet/transactions)
@Getter
@Setter
public class WalletTransactionResponse {

    private Long id;

    // DEPOSIT, WITHDRAWAL, DEBIT ou CREDIT
    private String type;

    private Double amount;

    private Double balanceAfter;

    // null pour débit/crédit
    private String method;

    private LocalDateTime createdAt;
}
