package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

// body pour depot/retrait/debit/credit sur le solde.
// method c'est juste pour info, pas utilisé pour debit/credit
@Getter
@Setter
public class WalletAmountRequest {

    private Double amount;

    private String method;
}
