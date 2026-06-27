package com.example.userservice.entity;

/**
 * Nature d'un mouvement du solde : dépôt/retrait initié par le patient, ou
 * débit/crédit lié à un rendez-vous (côté appointment-service).
 */
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
