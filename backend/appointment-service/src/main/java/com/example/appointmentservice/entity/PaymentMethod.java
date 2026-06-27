package com.example.appointmentservice.entity;

public enum PaymentMethod {

    SIMULATED_ORANGE_MONEY,
    SIMULATED_WAVE,
    SIMULATED_CARD,

    // Paiement débité du solde PsyConnect (cf. WalletClient) : seul moyen
    // utilisé pour payer un RDV. Les valeurs SIMULATED_* ci-dessus ne
    // qualifient plus qu'un dépôt/retrait sur le solde, pas un paiement direct.
    WALLET
}
