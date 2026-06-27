package com.example.appointmentservice.exception;

/**
 * Levée quand un service distant (user-service, notification-service) reste
 * indisponible après épuisement des tentatives de retry, ou quand le
 * circuit breaker correspondant est ouvert (échecs trop fréquents récents,
 * on échoue immédiatement sans même tenter l'appel). Traduite par
 * {@code GlobalExceptionHandler} en HTTP 503, pour que l'appelant distingue
 * "le service distant a un problème transitoire, réessayez" d'une erreur
 * de requête classique (400) ou métier (404/403).
 */
public class ServiceUnavailableException extends RuntimeException {

    public ServiceUnavailableException(String message) {
        super(message);
    }

    public ServiceUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
