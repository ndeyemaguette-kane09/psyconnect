package com.example.appointmentservice.controller;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.ObjectMapper;

import com.example.appointmentservice.dto.CreatePaymentRequest;
import com.example.appointmentservice.dto.PaymentResponse;
import com.example.appointmentservice.entity.PaymentMethod;
import com.example.appointmentservice.entity.PaymentStatus;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.repository.PaymentRepository;
import com.example.appointmentservice.repository.PlatformSettingsRepository;
import com.example.appointmentservice.security.JwtAuthenticationFilter;
import com.example.appointmentservice.service.PaymentService;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
    private PaymentRepository paymentRepository;

    @MockBean
    private AppointmentRepository appointmentRepository;

    @MockBean
    private PlatformSettingsRepository platformSettingsRepository;

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
}
