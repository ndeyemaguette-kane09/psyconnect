package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

// solde courant du patient
@Getter
@Setter
public class WalletResponse {

    private Long patientId;

    private Double balance;
}
