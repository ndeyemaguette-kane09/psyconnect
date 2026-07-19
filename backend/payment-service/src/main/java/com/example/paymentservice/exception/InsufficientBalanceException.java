package com.example.paymentservice.exception;

// solde insuffisant, pas une panne donc pas de retry dessus
public class InsufficientBalanceException extends RuntimeException {

    public InsufficientBalanceException(String message) {
        super(message);
    }
}
