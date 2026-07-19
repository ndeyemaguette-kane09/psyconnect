package com.example.paymentservice.controller;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.ObjectMapper;

import com.example.paymentservice.dto.CreatePaymentRequest;
import com.example.paymentservice.dto.PaymentResponse;
import com.example.paymentservice.entity.PaymentMethod;
import com.example.paymentservice.entity.PaymentStatus;
import com.example.paymentservice.security.JwtAuthenticationFilter;
import com.example.paymentservice.service.PaymentService;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// migre depuis appointment-service apres l'extraction du paiement en
// microservice a part ; PaymentController n'a plus qu'une seule dependance
// (PaymentService), donc plus besoin de mocker des repositories ici
@WebMvcTest(PaymentController.class)
@AutoConfigureMockMvc(addFilters = false)
class PaymentControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private PaymentService paymentService;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Test
    void createPayment_validRequest_returnsCreated() throws Exception {

        CreatePaymentRequest request = new CreatePaymentRequest();
        request.setAppointmentId(1L);
        request.setAmount(new BigDecimal("10000"));
        request.setMethod(PaymentMethod.SIMULATED_WAVE);

        PaymentResponse response = new PaymentResponse();
        response.setId(1L);
        response.setAppointmentId(1L);
        response.setStatus(PaymentStatus.COMPLETED);
        response.setTransactionReference("SIM-xyz");

        when(paymentService.createPayment(any(CreatePaymentRequest.class)))
                .thenReturn(response);

        mockMvc.perform(post("/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.transactionReference").value("SIM-xyz"))
                .andExpect(jsonPath("$.status").value("COMPLETED"));
    }

    @Test
    void createPayment_missingFields_returnsBadRequest() throws Exception {

        mockMvc.perform(post("/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void getPaymentById_returnsOk() throws Exception {

        PaymentResponse response = new PaymentResponse();
        response.setId(7L);
        response.setStatus(PaymentStatus.COMPLETED);

        when(paymentService.getPaymentById(7L)).thenReturn(response);

        mockMvc.perform(get("/payments/7"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(7));
    }

    @Test
    void getPaymentsByAppointmentId_returnsOk() throws Exception {

        PaymentResponse response = new PaymentResponse();
        response.setId(1L);
        response.setAppointmentId(5L);
        response.setStatus(PaymentStatus.COMPLETED);

        when(paymentService.getPaymentsByAppointmentId(5L))
                .thenReturn(java.util.List.of(response));

        mockMvc.perform(get("/payments/appointment/5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].appointmentId").value(5));
    }

    @Test
    void refundCompletedPayments_returnsOk() throws Exception {

        when(paymentService.refundCompletedPayments(eq(5L), eq(10L)))
                .thenReturn(new BigDecimal("15000"));

        mockMvc.perform(post("/payments/appointment/5/refund?patientId=10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").value(15000));
    }
}
