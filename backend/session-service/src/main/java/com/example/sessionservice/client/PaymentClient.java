package com.example.sessionservice.client;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import com.example.sessionservice.exception.ServiceUnavailableException;
import com.example.sessionservice.security.SecurityUtils;

@Component
public class PaymentClient {

    private final RestTemplate restTemplate;
    private final String paymentServiceUrl;

    public PaymentClient(
            RestTemplate restTemplate,
            @Value("${services.payment.url}") String paymentServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.paymentServiceUrl = paymentServiceUrl;
    }

    public boolean isPaid(Long appointmentId) {
        HttpHeaders headers = new HttpHeaders();
        String auth = SecurityUtils.currentAuthorizationHeader();
        if (auth != null) headers.set("Authorization", auth);
        try {
            List<Map<String, Object>> payments = restTemplate.exchange(
                    paymentServiceUrl + "/payments/appointment/" + appointmentId,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    new ParameterizedTypeReference<List<Map<String, Object>>>() { }
            ).getBody();
            return payments != null
                    && payments.stream().anyMatch(p -> "COMPLETED".equals(String.valueOf(p.get("status"))));
        } catch (RestClientException ex) {
            throw new ServiceUnavailableException("Impossible de vérifier le paiement de ce rendez-vous", ex);
        }
    }
}
