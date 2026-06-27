package com.example.appointmentservice.service;

import java.util.Map;

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

import com.example.appointmentservice.exception.ServiceUnavailableException;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Démontre, avec un vrai contexte Spring (les annotations Resilience4j ne
 * sont actives qu'à travers un proxy AOP géré par Spring — un simple
 * {@code new OwnershipResolver(...)} dans un test Mockito pur les
 * ignorerait totalement), que :
 *
 * 1) un échec transitoire de user-service est ré-essayé automatiquement
 *    ({@code @Retry}, 3 tentatives — voir application.properties de test)
 *    avant que l'appel ne soit considéré en échec ;
 * 2) des échecs répétés font basculer le circuit breaker en état OPEN, qui
 *    fait alors échouer les appels suivants immédiatement, sans même
 *    solliciter user-service (CallNotPermittedException côté
 *    Resilience4j, traduite en {@link ServiceUnavailableException} par le
 *    fallback).
 */
@SpringBootTest
class OwnershipResolverResilienceTest {

    @Autowired
    private OwnershipResolver ownershipResolver;

    @Autowired
    private CircuitBreakerRegistry circuitBreakerRegistry;

    @MockBean
    private RestTemplate restTemplate;

    @BeforeEach
    void setUp() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute("authUserId", 42L);
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));

        // Le registre est partagé entre les tests (et potentiellement
        // réutilisé entre classes via le cache de contexte Spring) : on
        // repart d'un état CLOSED pour ne pas dépendre de l'ordre
        // d'exécution.
        circuitBreakerRegistry.circuitBreaker("userService").reset();
    }

    @AfterEach
    void tearDown() {
        RequestContextHolder.resetRequestAttributes();
    }

    @Test
    void resolveOwnPatientId_transientFailure_retriesThenThrowsServiceUnavailable() {

        when(restTemplate.exchange(anyString(), any(), any(), eq(Map.class)))
                .thenThrow(new RestClientException("user-service indisponible"));

        assertThrows(
                ServiceUnavailableException.class,
                ownershipResolver::resolveOwnPatientId
        );

        // max-attempts=3 (application.properties de test) : un seul appel
        // logique déclenche 3 tentatives RestTemplate avant d'abandonner.
        verify(restTemplate, times(3))
                .exchange(anyString(), any(), any(), eq(Map.class));
    }

    @Test
    void resolveOwnPatientId_repeatedFailures_opensCircuitAndStopsCallingUserService() {

        when(restTemplate.exchange(anyString(), any(), any(), eq(Map.class)))
                .thenThrow(new RestClientException("user-service indisponible"));

        // minimum-number-of-calls=4 (config de test) : on remplit la
        // fenêtre glissante avec des échecs pour faire basculer le circuit.
        for (int i = 0; i < 4; i++) {
            assertThrows(
                    ServiceUnavailableException.class,
                    ownershipResolver::resolveOwnPatientId
            );
        }

        CircuitBreaker circuitBreaker = circuitBreakerRegistry.circuitBreaker("userService");
        assertEquals(CircuitBreaker.State.OPEN, circuitBreaker.getState());

        clearInvocations(restTemplate);

        assertThrows(
                ServiceUnavailableException.class,
                ownershipResolver::resolveOwnPatientId
        );

        // Circuit ouvert : échec immédiat, sans tenter d'appeler user-service.
        verify(restTemplate, never())
                .exchange(anyString(), any(), any(), eq(Map.class));
    }
}
