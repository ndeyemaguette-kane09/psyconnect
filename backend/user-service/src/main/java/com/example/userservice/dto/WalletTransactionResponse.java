package com.example.userservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

/** Une ligne du relevé du solde PsyConnect (GET /patients/{id}/wallet/transactions). */
@Getter
@Setter
public class WalletTransactionResponse {

    private Long id;

    /** DEPOSIT, WITHDRAWAL, DEBIT ou CREDIT. */
    private String type;

    private Double amount;

    private Double balanceAfter;

    /** Moyen mobile money simulé (dépôt/retrait), null pour débit/crédit. */
    private String method;

    private LocalDateTime createdAt;
}
