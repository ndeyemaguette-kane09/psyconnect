package com.example.paymentservice.client;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import com.example.paymentservice.exception.InsufficientBalanceException;
import com.example.paymentservice.exception.ServiceUnavailableException;
import com.example.paymentservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

// Débit/crédit du solde wallet (côté user-service), pour payer/rembourser un rendez-vous
@Component
public class WalletClient {

    private final RestTemplate restTemplate;
    private final String userServiceUrl;

    public WalletClient(
            RestTemplate restTemplate,
            @Value("${services.user.url}") String userServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.userServiceUrl = userServiceUrl;
    }

    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackDebit")
    public void debit(Long patientId, Double amount) {
        call(patientId, "debit", amount);
    }

    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackCredit")
    public void credit(Long patientId, Double amount) {
        call(patientId, "credit", amount);
    }

    private void call(Long patientId, String operation, Double amount) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", SecurityUtils.currentAuthorizationHeader());

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(
                Map.of("amount", amount), headers
        );

        restTemplate.exchange(
                userServiceUrl + "/patients/" + patientId + "/wallet/" + operation,
                HttpMethod.POST,
                entity,
                Void.class
        );
    }

    // fallback appelé seulement apres echec des retries (Retry enveloppe CircuitBreaker)
    private void fallbackDebit(Long patientId, Double amount, Exception ex) {
        if (ex instanceof HttpClientErrorException httpEx
                && httpEx.getStatusCode().equals(HttpStatus.PAYMENT_REQUIRED)) {
            throw new InsufficientBalanceException("Solde insuffisant");
        }
        throw new ServiceUnavailableException("Le service utilisateur est indisponible, réessayez plus tard", ex);
    }

    private void fallbackCredit(Long patientId, Double amount, Exception ex) {
        throw new ServiceUnavailableException("Le service utilisateur est indisponible, réessayez plus tard", ex);
    }
}
