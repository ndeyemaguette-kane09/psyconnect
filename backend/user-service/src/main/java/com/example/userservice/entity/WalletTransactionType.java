package com.example.userservice.entity;

public enum WalletTransactionType {

    /** Recharge simulée (Wave/Orange Money/Carte) initiée par le patient. */
    DEPOSIT,

    /** Retrait simulé vers Wave/Orange Money, initié par le patient. */
    WITHDRAWAL,

    /** Paiement d'un rendez-vous, débité par appointment-service. */
    DEBIT,

    /** Remboursement d'un rendez-vous annulé, crédité par appointment-service. */
    CREDIT
}
