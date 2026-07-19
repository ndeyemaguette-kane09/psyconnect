package com.example.authservice.exception;

// Levée quand un utilisateur dont le compte est désactivé (enabled = false)
// tente de se connecter. Traitée séparément des autres RuntimeException
// pour renvoyer HTTP 403 + errorCode ACCOUNT_BANNED côté Flutter.
public class BannedAccountException extends RuntimeException {
    public BannedAccountException() {
        super("Votre compte a été suspendu par l'administrateur. "
            + "Contactez-nous pour plus d'informations.");
    }
}
