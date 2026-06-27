package com.example.appointmentservice.exception;

/**
 * Levée quand le solde PsyConnect du patient est insuffisant pour un débit
 * (paiement d'un rendez-vous). Distincte d'une {@link RuntimeException}
 * générique pour pouvoir l'exclure du périmètre retry/circuit breaker de
 * {@link com.example.appointmentservice.client.WalletClient} — un solde
 * insuffisant est une erreur métier, pas une panne de user-service, donc
 * pas la peine de réessayer (cf. même logique que ResourceNotFoundException
 * / ForbiddenOperationException pour OwnershipResolver).
 */
public class InsufficientBalanceException extends RuntimeException {

    public InsufficientBalanceException(String message) {
        super(message);
    }
}
