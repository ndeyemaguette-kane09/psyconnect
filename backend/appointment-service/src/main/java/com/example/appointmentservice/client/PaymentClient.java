package com.example.appointmentservice.client;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import com.example.appointmentservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

// appelle payment-service pour rembourser un RDV annulé (>48h avant le
// début) ; on lui passe directement le patientId déjà en mémoire, pas
// besoin que payment-service revienne nous le demander
@Component
public class PaymentClient {

    private static final Logger LOGGER = LoggerFactory.getLogger(PaymentClient.class);

    private final RestTemplate restTemplate;
    private final String paymentServiceUrl;

    public PaymentClient(
            RestTemplate restTemplate,
            @Value("${services.payment.url}") String paymentServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.paymentServiceUrl = paymentServiceUrl;
    }

    @CircuitBreaker(name = "paymentService")
    @Retry(name = "paymentService", fallbackMethod = "fallbackRefund")
    public void refundCompletedPayments(Long appointmentId, Long patientId) {

        HttpHeaders headers = new HttpHeaders();
        String authorization = SecurityUtils.currentAuthorizationHeader();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        restTemplate.exchange(
                paymentServiceUrl + "/payments/appointment/" + appointmentId
                        + "/refund?patientId=" + patientId,
                HttpMethod.POST,
                new HttpEntity<>(headers),
                Void.class
        );
    }

    // Si payment-service est indisponible, l'annulation s'effectue quand même mais sans
    // remboursement automatique ; on logue fort pour un traitement manuel
    private void fallbackRefund(Long appointmentId, Long patientId, Throwable t) {
        LOGGER.error(
                "Remboursement automatique impossible pour le rendez-vous {} (patient {}) : "
                        + "payment-service indisponible (retry épuisé ou circuit ouvert). "
                        + "Un remboursement manuel est nécessaire.",
                appointmentId,
                patientId,
                t
        );
    }
}
