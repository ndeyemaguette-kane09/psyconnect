package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

/** Solde PsyConnect courant d'un patient (cf. PatientProfile.walletBalance). */
@Getter
@Setter
public class WalletResponse {

    private Long patientId;

    private Double balance;
}
