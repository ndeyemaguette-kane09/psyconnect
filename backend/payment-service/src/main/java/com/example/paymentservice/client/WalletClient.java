package com.example.paymentservice.client;

import java.util.HashMap;
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
import com.example.paymentservice.security.ServiceTokenProvider;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

// Débit/crédit du solde wallet (côté user-service), pour payer/rembourser un rendez-vous
@Component
public class WalletClient {

    private final RestTemplate restTemplate;
    private final String userServiceUrl;
    private final ServiceTokenProvider serviceTokenProvider;

    public WalletClient(
            RestTemplate restTemplate,
            @Value("${services.user.url}") String userServiceUrl,
            ServiceTokenProvider serviceTokenProvider
    ) {
        this.restTemplate = restTemplate;
        this.userServiceUrl = userServiceUrl;
        this.serviceTokenProvider = serviceTokenProvider;
    }

    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackDebit")
    public void debit(Long patientId, Double amount, String operationKey) {
        call(patientId, "debit", amount, operationKey, SecurityUtils.currentAuthorizationHeader());
    }

    // appelés aussi par l'outbox, hors requête patient : jeton de service
    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackCredit")
    public void credit(Long patientId, Double amount, String operationKey) {
        call(patientId, "credit", amount, operationKey, serviceTokenProvider.authorizationHeader());
    }

    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackReverse")
    public void reverseDebit(Long patientId, String debitOperationKey) {
        call(patientId, "reverse", null, debitOperationKey, serviceTokenProvider.authorizationHeader());
    }

    private void call(Long patientId, String operation, Double amount,
                      String operationKey, String authorization) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", authorization);

        Map<String, Object> body = new HashMap<>();
        if (amount != null) body.put("amount", amount);
        body.put("operationKey", operationKey);

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

        restTemplate.exchange(
                userServiceUrl + "/patients/" + patientId + "/wallet/" + operation,
                HttpMethod.POST,
                entity,
                Void.class
        );
    }

    // fallback appelé seulement apres echec des retries (Retry enveloppe CircuitBreaker)
    private void fallbackDebit(Long patientId, Double amount, String operationKey, Exception ex) {
        if (ex instanceof HttpClientErrorException httpEx
                && httpEx.getStatusCode().equals(HttpStatus.PAYMENT_REQUIRED)) {
            throw new InsufficientBalanceException("Solde insuffisant");
        }
        throw new ServiceUnavailableException("Le service utilisateur est indisponible, réessayez plus tard", ex);
    }

    private void fallbackCredit(Long patientId, Double amount, String operationKey, Exception ex) {
        throw new ServiceUnavailableException("Le service utilisateur est indisponible, réessayez plus tard", ex);
    }

    private void fallbackReverse(Long patientId, String debitOperationKey, Exception ex) {
        throw new ServiceUnavailableException("Le service utilisateur est indisponible, réessayez plus tard", ex);
    }
}
