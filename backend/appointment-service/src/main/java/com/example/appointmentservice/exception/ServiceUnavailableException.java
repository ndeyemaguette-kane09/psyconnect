package com.example.appointmentservice.exception;

// service distant (user-service/notification-service) down apres retry épuisé
// ou circuit ouvert. GlobalExceptionHandler la traduit en 503
public class ServiceUnavailableException extends RuntimeException {

    public ServiceUnavailableException(String message) {
        super(message);
    }

    public ServiceUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
