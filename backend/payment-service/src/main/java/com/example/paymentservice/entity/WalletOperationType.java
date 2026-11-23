package com.example.paymentservice.entity;

public enum WalletOperationType {

    // annule le débit d'un paiement qui n'a pas abouti
    REVERSE_DEBIT,

    // rembourse un rendez-vous annulé
    CREDIT
}
