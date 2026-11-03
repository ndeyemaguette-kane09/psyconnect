package com.example.userservice.entity;

public enum WalletTransactionType {

    // recharge simulée (Wave, Orange Money, carte)
    DEPOSIT,

    // retrait simulé vers Wave ou Orange Money
    WITHDRAWAL,

    // paiement d'un RDV
    DEBIT,

    // remboursement d'un RDV annulé
    CREDIT
}
