package com.example.appointmentservice.client;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import com.example.appointmentservice.security.SecurityUtils;
import com.example.appointmentservice.security.ServiceTokenProvider;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

@Component
public class PaymentClient {

    private static final Logger LOGGER = LoggerFactory.getLogger(PaymentClient.class);

    private final RestTemplate restTemplate;
    private final String paymentServiceUrl;
    private final ServiceTokenProvider serviceTokenProvider;

    public PaymentClient(
            RestTemplate restTemplate,
            @Value("${services.payment.url}") String paymentServiceUrl,
            ServiceTokenProvider serviceTokenProvider
    ) {
        this.restTemplate = restTemplate;
        this.paymentServiceUrl = paymentServiceUrl;
        this.serviceTokenProvider = serviceTokenProvider;
    }

    @CircuitBreaker(name = "paymentService")
    @Retry(name = "paymentService")
    public boolean hasCompletedPayment(Long appointmentId) {

        String authorization = null;
        try {
            authorization = SecurityUtils.currentAuthorizationHeader();
        } catch (IllegalStateException ignored) {
        }

        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization",
                authorization != null ? authorization : serviceTokenProvider.authorizationHeader());

        List<Map<String, Object>> payments = restTemplate.exchange(
                paymentServiceUrl + "/payments/appointment/" + appointmentId,
                HttpMethod.GET,
                new HttpEntity<>(headers),
                new ParameterizedTypeReference<List<Map<String, Object>>>() { }
        ).getBody();

        return payments != null
                && payments.stream().anyMatch(p -> "COMPLETED".equals(String.valueOf(p.get("status"))));
    }

    @CircuitBreaker(name = "paymentService")
    @Retry(name = "paymentService", fallbackMethod = "fallbackRefund")
    public void refundCompletedPayments(Long appointmentId, Long patientId) {

        String authorization = null;
        try {
            authorization = SecurityUtils.currentAuthorizationHeader();
        } catch (IllegalStateException ignored) {
        }

        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization",
                authorization != null ? authorization : serviceTokenProvider.authorizationHeader());

        restTemplate.exchange(
                paymentServiceUrl + "/payments/appointment/" + appointmentId
                        + "/refund?patientId=" + patientId,
                HttpMethod.POST,
                new HttpEntity<>(headers),
                Void.class
        );
    }

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
