package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

/**
 * Corps de requête pour les opérations sur le solde PsyConnect.
 *
 * - Dépôt / retrait (initiés par le patient depuis l'écran "Mon solde") :
 *   {@code method} indique le moyen mobile money simulé (Wave/Orange Money)
 *   utilisé côté Yassir-like, purement informatif (aucune intégration
 *   réelle).
 * - Débit / crédit (appelés par appointment-service lors d'un paiement ou
 *   d'un remboursement de rendez-vous) : {@code method} est ignoré/absent,
 *   seul {@code amount} compte.
 */
@Getter
@Setter
public class WalletAmountRequest {

    private Double amount;

    private String method;
}
