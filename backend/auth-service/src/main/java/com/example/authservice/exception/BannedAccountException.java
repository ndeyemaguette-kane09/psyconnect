package com.example.authservice.exception;

public class BannedAccountException extends RuntimeException {
    public BannedAccountException() {
        super("Votre compte a été suspendu par l'administrateur. "
            + "Contactez-nous pour plus d'informations.");
    }
}
