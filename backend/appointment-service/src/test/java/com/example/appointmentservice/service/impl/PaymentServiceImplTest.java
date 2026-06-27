package com.example.appointmentservice.service.impl;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import com.example.appointmentservice.client.NotificationClient;
import com.example.appointmentservice.client.WalletClient;
import com.example.appointmentservice.dto.CreatePaymentRequest;
import com.example.appointmentservice.dto.PaymentResponse;
import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.entity.Payment;
import com.example.appointmentservice.entity.PaymentMethod;
import com.example.appointmentservice.entity.PaymentStatus;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.repository.PaymentRepository;
import com.example.appointmentservice.service.OwnershipResolver;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PaymentServiceImplTest {

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private AppointmentRepository appointmentRepository;

    // Le client de notification est désormais le seul point de contact avec
    // notification-service (retry/circuit breaker Resilience4j vivent à
    // l'intérieur, voir NotificationClientResilienceTest) : ici on vérifie
    // uniquement que PaymentServiceImpl l'appelle correctement, sans
    // ré-implémenter ses tests de résilience.
    @Mock
    private NotificationClient notificationClient;

    @Mock
    private OwnershipResolver ownershipResolver;

    // WalletClient.debit/credit sont des méthodes void mockées sans
    // comportement particulier (cf. WalletClientTest pour leur résilience) :
    // ici on vérifie seulement que PaymentServiceImpl les appelle au bon
    // moment, dans le bon ordre par rapport aux autres vérifications.
    @Mock
    private WalletClient walletClient;

    private PaymentServiceImpl paymentService;

    @BeforeEach
    void setUp() {
        paymentService = new PaymentServiceImpl(
                paymentRepository,
                appointmentRepository,
                notificationClient,
                ownershipResolver,
                walletClient
        );

        RequestContextHolder.setRequestAttributes(
                new ServletRequestAttributes(new MockHttpServletRequest())
        );
    }

    @AfterEach
    void tearDown() {
        RequestContextHolder.resetRequestAttributes();
        SecurityContextHolder.clearContext();
    }

    /**
     * Simule un appelant authentifié avec le rôle PATIENT, propriétaire du
     * rendez-vous dont l'id patient est {@code ownPatientId}.
     */
    private void authenticateAsPatientOwning(Long ownPatientId) {
        SecurityContextHolder.getContext().setAuthentication(
                new TestingAuthenticationToken("patient", null, "ROLE_PATIENT")
        );
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(ownPatientId);
    }

    private CreatePaymentRequest buildRequest(Long appointmentId, String amount, PaymentMethod method) {
        CreatePaymentRequest request = new CreatePaymentRequest();
        request.setAppointmentId(appointmentId);
        request.setAmount(new BigDecimal(amount));
        request.setMethod(method);
        return request;
    }

    @Test
    void createPayment_success_debitsWalletAndSendsNotification() {

        // Le rendez-vous doit déjà être CONFIRMED par le psychologue avant
        // de pouvoir être payé : le paiement ne confirme plus lui-même un
        // RDV encore PENDING.
        Appointment appointment = new Appointment();
        appointment.setId(1L);
        appointment.setPatientId(10L);
        appointment.setPsychologistId(20L);
        appointment.setStatus(AppointmentStatus.CONFIRMED);

        authenticateAsPatientOwning(10L);

        when(appointmentRepository.findById(1L)).thenReturn(Optional.of(appointment));
        // Aucun paiement COMPLETED existant pour ce RDV : la garde anti
        // double-paiement laisse passer.
        when(paymentRepository.findByAppointmentId(1L)).thenReturn(List.of());
        when(paymentRepository.save(any(Payment.class))).thenAnswer(invocation -> {
            Payment saved = invocation.getArgument(0);
            saved.setId(100L);
            return saved;
        });

        PaymentResponse response = paymentService.createPayment(
                buildRequest(1L, "15000", PaymentMethod.SIMULATED_WAVE)
        );

        assertEquals(100L, response.getId());
        assertEquals(PaymentStatus.COMPLETED, response.getStatus());
        assertNotNull(response.getTransactionReference());

        verify(walletClient).debit(10L, 15000.0);
        verify(notificationClient).send(
                eq(10L),
                eq("Paiement confirmé"),
                any(String.class),
                eq("PAYMENT")
        );
    }

    @Test
    void createPayment_pendingAppointment_throwsBeforeDebiting() {

        // Doit échouer AVANT tout débit du solde : un RDV encore PENDING ne
        // peut pas être payé.
        Appointment appointment = new Appointment();
        appointment.setId(4L);
        appointment.setPatientId(10L);
        appointment.setStatus(AppointmentStatus.PENDING);

        authenticateAsPatientOwning(10L);

        when(appointmentRepository.findById(4L)).thenReturn(Optional.of(appointment));

        assertThrows(
                RuntimeException.class,
                () -> paymentService.createPayment(
                        buildRequest(4L, "5000", PaymentMethod.SIMULATED_CARD)
                )
        );

        verify(paymentRepository, never()).save(any());
    }

    @Test
    void createPayment_alreadyPaid_throwsAndDoesNotDebitTwice() {

        // Un double-clic sur "Payer" ne doit pas débiter deux fois : un
        // paiement COMPLETED existant doit bloquer toute nouvelle tentative.
        Appointment appointment = new Appointment();
        appointment.setId(1L);
        appointment.setPatientId(10L);
        appointment.setStatus(AppointmentStatus.CONFIRMED);

        Payment existingPayment = new Payment();
        existingPayment.setId(100L);
        existingPayment.setAppointmentId(1L);
        existingPayment.setStatus(PaymentStatus.COMPLETED);

        authenticateAsPatientOwning(10L);

        when(appointmentRepository.findById(1L)).thenReturn(Optional.of(appointment));
        when(paymentRepository.findByAppointmentId(1L)).thenReturn(List.of(existingPayment));

        assertThrows(
                RuntimeException.class,
                () -> paymentService.createPayment(
                        buildRequest(1L, "15000", PaymentMethod.SIMULATED_WAVE)
                )
        );

        verify(walletClient, never()).debit(any(), any());
        verify(paymentRepository, never()).save(any());
    }

    @Test
    void createPayment_appointmentNotFound_throwsAndDoesNotSave() {

        when(appointmentRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(
                RuntimeException.class,
                () -> paymentService.createPayment(
                        buildRequest(99L, "5000", PaymentMethod.SIMULATED_CARD)
                )
        );

        verify(paymentRepository, never()).save(any());
    }

    @Test
    void createPayment_notOwnAppointment_throwsForbidden() {

        Appointment appointment = new Appointment();
        appointment.setId(1L);
        appointment.setPatientId(10L);
        appointment.setStatus(AppointmentStatus.PENDING);

        // Authentifié comme patient, mais propriétaire d'un AUTRE profil patient.
        authenticateAsPatientOwning(999L);

        when(appointmentRepository.findById(1L)).thenReturn(Optional.of(appointment));

        assertThrows(
                RuntimeException.class,
                () -> paymentService.createPayment(
                        buildRequest(1L, "15000", PaymentMethod.SIMULATED_WAVE)
                )
        );

        verify(paymentRepository, never()).save(any());
    }

    @Test
    void createPayment_cancelledAppointment_throws() {

        Appointment appointment = new Appointment();
        appointment.setId(2L);
        appointment.setPatientId(10L);
        appointment.setStatus(AppointmentStatus.CANCELLED);

        authenticateAsPatientOwning(10L);

        when(appointmentRepository.findById(2L)).thenReturn(Optional.of(appointment));

        assertThrows(
                RuntimeException.class,
                () -> paymentService.createPayment(
                        buildRequest(2L, "5000", PaymentMethod.SIMULATED_CARD)
                )
        );

        verify(paymentRepository, never()).save(any());
    }

    @Test
    void createPayment_rejectedAppointment_throws() {

        Appointment appointment = new Appointment();
        appointment.setId(3L);
        appointment.setPatientId(10L);
        appointment.setStatus(AppointmentStatus.REJECTED);

        authenticateAsPatientOwning(10L);

        when(appointmentRepository.findById(3L)).thenReturn(Optional.of(appointment));

        assertThrows(
                RuntimeException.class,
                () -> paymentService.createPayment(
                        buildRequest(3L, "5000", PaymentMethod.SIMULATED_CARD)
                )
        );
    }

    @Test
    void getPaymentById_notFound_throws() {

        when(paymentRepository.findById(404L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> paymentService.getPaymentById(404L));
    }

    @Test
    void getPaymentById_found_returnsMappedResponse() {

        Payment payment = new Payment();
        payment.setId(7L);
        payment.setAppointmentId(1L);
        payment.setAmount(new BigDecimal("3000"));
        payment.setMethod(PaymentMethod.SIMULATED_CARD);
        payment.setStatus(PaymentStatus.COMPLETED);
        payment.setTransactionReference("SIM-test");

        Appointment appointment = new Appointment();
        appointment.setId(1L);
        appointment.setPatientId(10L);

        authenticateAsPatientOwning(10L);

        when(paymentRepository.findById(7L)).thenReturn(Optional.of(payment));
        when(appointmentRepository.findById(1L)).thenReturn(Optional.of(appointment));

        PaymentResponse response = paymentService.getPaymentById(7L);

        assertEquals(7L, response.getId());
        assertEquals("SIM-test", response.getTransactionReference());
    }

    @Test
    void getPaymentsByAppointmentId_returnsMappedList() {

        Payment payment = new Payment();
        payment.setId(1L);
        payment.setAppointmentId(5L);
        payment.setAmount(new BigDecimal("1000"));
        payment.setMethod(PaymentMethod.SIMULATED_CARD);
        payment.setStatus(PaymentStatus.COMPLETED);
        payment.setTransactionReference("SIM-abc");

        Appointment appointment = new Appointment();
        appointment.setId(5L);
        appointment.setPatientId(10L);

        authenticateAsPatientOwning(10L);

        when(appointmentRepository.findById(5L)).thenReturn(Optional.of(appointment));
        when(paymentRepository.findByAppointmentId(5L)).thenReturn(List.of(payment));

        List<PaymentResponse> result = paymentService.getPaymentsByAppointmentId(5L);

        assertEquals(1, result.size());
        assertEquals("SIM-abc", result.get(0).getTransactionReference());
    }
}
