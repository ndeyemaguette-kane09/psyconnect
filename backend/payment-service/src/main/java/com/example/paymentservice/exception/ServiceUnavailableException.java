package com.example.paymentservice.exception;

// service distant (appointment/user/notification-service) down apres retry
// epuise ou circuit ouvert. GlobalExceptionHandler la traduit en 503
public class ServiceUnavailableException extends RuntimeException {

    public ServiceUnavailableException(String message) {
        super(message);
    }

    public ServiceUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
