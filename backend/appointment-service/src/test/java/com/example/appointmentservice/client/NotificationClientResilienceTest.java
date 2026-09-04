package com.example.appointmentservice.client;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Démontre que l'envoi de notification reste "best effort" même sous
 * Resilience4j : le contrat de {@link NotificationClient#send} est de ne
 * JAMAIS répercuter une panne de notification-service sur l'appelant
 * (paiement, rendez-vous, session). On vérifie ici à la fois le retry (3
 * tentatives) et l'ouverture du circuit breaker (échec rapide, sans
 * solliciter à nouveau notification-service), tout en confirmant qu'aucune
 * exception ne fuite jamais vers l'appelant.
 */
@SpringBootTest
class NotificationClientResilienceTest {

    @Autowired
    private NotificationClient notificationClient;

    @Autowired
    private CircuitBreakerRegistry circuitBreakerRegistry;

    @MockBean
    private RestTemplate restTemplate;

    @BeforeEach
    void setUp() {
        RequestContextHolder.setRequestAttributes(
                new ServletRequestAttributes(new MockHttpServletRequest())
        );
        circuitBreakerRegistry.circuitBreaker("notificationService").reset();
    }

    @AfterEach
    void tearDown() {
        RequestContextHolder.resetRequestAttributes();
    }

    @Test
    void send_transientFailure_retriesThenFallsBackSilently() {

        when(restTemplate.exchange(anyString(), any(), any(), eq(Object.class)))
                .thenThrow(new RestClientException("notification-service indisponible"));

        assertDoesNotThrow(() ->
                notificationClient.send(1L, "Titre", "Message", "TYPE", "PATIENT")
        );

        // max-attempts=3 (application.properties de test).
        verify(restTemplate, times(3))
                .exchange(anyString(), any(), any(), eq(Object.class));
    }

    @Test
    void send_repeatedFailures_opensCircuitAndStopsCallingNotificationService() {

        when(restTemplate.exchange(anyString(), any(), any(), eq(Object.class)))
                .thenThrow(new RestClientException("notification-service indisponible"));

        for (int i = 0; i < 4; i++) {
            assertDoesNotThrow(() ->
                    notificationClient.send(1L, "Titre", "Message", "TYPE", "PATIENT")
            );
        }

        CircuitBreaker circuitBreaker = circuitBreakerRegistry.circuitBreaker("notificationService");
        assertEquals(CircuitBreaker.State.OPEN, circuitBreaker.getState());

        clearInvocations(restTemplate);

        assertDoesNotThrow(() ->
                notificationClient.send(1L, "Titre", "Message", "TYPE", "PATIENT")
        );

        verify(restTemplate, never())
                .exchange(anyString(), any(), any(), eq(Object.class));
    }
}
