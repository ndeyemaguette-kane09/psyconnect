package com.example.paymentservice.entity;

public enum PaymentMethod {

    SIMULATED_ORANGE_MONEY,
    SIMULATED_WAVE,
    SIMULATED_CARD,

    // seul moyen pour payer un RDV, les autres c'est juste pour le solde
    WALLET
}
