package com.example.paymentservice.service.impl;

import java.math.BigDecimal;
import java.time.LocalDateTime;
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

import com.example.paymentservice.client.AppointmentClient;
import com.example.paymentservice.client.NotificationClient;
import com.example.paymentservice.client.WalletClient;
import com.example.paymentservice.dto.AppointmentSummary;
import com.example.paymentservice.dto.CreatePaymentRequest;
import com.example.paymentservice.dto.PaymentResponse;
import com.example.paymentservice.entity.Payment;
import com.example.paymentservice.entity.PaymentMethod;
import com.example.paymentservice.entity.PaymentStatus;
import com.example.paymentservice.exception.ForbiddenOperationException;
import com.example.paymentservice.repository.PaymentRepository;
import com.example.paymentservice.repository.PlatformSettingsRepository;
import com.example.paymentservice.repository.PsychologistWithdrawalRepository;
import com.example.paymentservice.service.OwnershipResolver;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

// migre depuis appointment-service apres l'extraction du paiement en
// microservice a part : AppointmentRepository -> AppointmentClient (l'acces
// au RDV passe maintenant par un appel HTTP a appointment-service, retourne
// sous forme allegee AppointmentSummary avec status en String)
@ExtendWith(MockitoExtension.class)
class PaymentServiceImplTest {

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private PlatformSettingsRepository platformSettingsRepository;

    @Mock
    private PsychologistWithdrawalRepository psychologistWithdrawalRepository;

    @Mock
    private AppointmentClient appointmentClient;

    // on verifie juste que PaymentServiceImpl appelle bien le client notif
    @Mock
    private NotificationClient notificationClient;

    @Mock
    private OwnershipResolver ownershipResolver;

    // on verifie juste que debit/credit sont appelés au bon moment
    @Mock
    private WalletClient walletClient;

    private PaymentServiceImpl paymentService;

    @BeforeEach
    void setUp() {
        paymentService = new PaymentServiceImpl(
                paymentRepository,
                platformSettingsRepository,
                psychologistWithdrawalRepository,
                appointmentClient,
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

    private AppointmentSummary buildAppointment(Long id, Long patientId, String status) {
        AppointmentSummary appointment = new AppointmentSummary();
        appointment.setId(id);
        appointment.setPatientId(patientId);
        appointment.setStatus(status);
        return appointment;
    }

    @Test
    void createPayment_success_debitsWalletAndSendsNotification() {

        // le RDV doit deja etre CONFIRMED pour pouvoir etre payé
        AppointmentSummary appointment = buildAppointment(1L, 10L, "CONFIRMED");

        authenticateAsPatientOwning(10L);

        when(appointmentClient.getAppointmentById(1L)).thenReturn(appointment);
        // pas de paiement existant, donc ca passe
        when(paymentRepository.findByAppointmentId(1L)).thenReturn(List.of());
        when(ownershipResolver.getConsultationPrice(any())).thenReturn(new BigDecimal("15000"));
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
                eq("PAYMENT"),
                eq("PATIENT")
        );
    }

    @Test
    void createPayment_ignoresAmountSentByClient_andDebitsConsultationPrice() {

        AppointmentSummary appointment = buildAppointment(1L, 10L, "CONFIRMED");

        authenticateAsPatientOwning(10L);

        when(appointmentClient.getAppointmentById(1L)).thenReturn(appointment);
        when(paymentRepository.findByAppointmentId(1L)).thenReturn(List.of());
        when(ownershipResolver.getConsultationPrice(any())).thenReturn(new BigDecimal("15000"));
        when(paymentRepository.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        PaymentResponse response = paymentService.createPayment(
                buildRequest(1L, "1", PaymentMethod.SIMULATED_WAVE)
        );

        assertEquals(new BigDecimal("15000"), response.getAmount());
        verify(walletClient).debit(10L, 15000.0);
    }

    @Test
    void createPayment_missingConsultationPrice_throwsBeforeDebiting() {

        AppointmentSummary appointment = buildAppointment(1L, 10L, "CONFIRMED");

        authenticateAsPatientOwning(10L);

        when(appointmentClient.getAppointmentById(1L)).thenReturn(appointment);
        when(paymentRepository.findByAppointmentId(1L)).thenReturn(List.of());
        when(ownershipResolver.getConsultationPrice(any())).thenReturn(null);

        assertThrows(RuntimeException.class, () ->
                paymentService.createPayment(buildRequest(1L, "15000", PaymentMethod.SIMULATED_WAVE))
        );

        verify(walletClient, never()).debit(any(), any());
        verify(paymentRepository, never()).save(any());
    }

    @Test
    void createPayment_pendingAppointment_throwsBeforeDebiting() {

        // doit echouer avant de toucher au solde, un RDV PENDING se paie pas
        AppointmentSummary appointment = buildAppointment(4L, 10L, "PENDING");

        authenticateAsPatientOwning(10L);

        when(appointmentClient.getAppointmentById(4L)).thenReturn(appointment);

        assertThrows(
                RuntimeException.class,
                () -> paymentService.createPayment(
                        buildRequest(4L, "5000", PaymentMethod.SIMULATED_CARD)
                )
        );

        verify(paymentRepository, never()).save(any());
        verify(walletClient, never()).debit(any(), any());
    }

    @Test
    void createPayment_alreadyPaid_throwsAndDoesNotDebitTwice() {

        // un double-clic sur "Payer" doit pas débiter deux fois
        AppointmentSummary appointment = buildAppointment(1L, 10L, "CONFIRMED");

        Payment existingPayment = new Payment();
        existingPayment.setId(100L);
        existingPayment.setAppointmentId(1L);
        existingPayment.setStatus(PaymentStatus.COMPLETED);

        authenticateAsPatientOwning(10L);

        when(appointmentClient.getAppointmentById(1L)).thenReturn(appointment);
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

        when(appointmentClient.getAppointmentById(99L))
                .thenThrow(new RuntimeException("Rendez-vous non trouvé"));

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

        AppointmentSummary appointment = buildAppointment(1L, 10L, "PENDING");

        // Authentifié comme patient, mais propriétaire d'un AUTRE profil patient.
        authenticateAsPatientOwning(999L);

        when(appointmentClient.getAppointmentById(1L)).thenReturn(appointment);

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

        AppointmentSummary appointment = buildAppointment(2L, 10L, "CANCELLED");

        authenticateAsPatientOwning(10L);

        when(appointmentClient.getAppointmentById(2L)).thenReturn(appointment);

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

        AppointmentSummary appointment = buildAppointment(3L, 10L, "REJECTED");

        authenticateAsPatientOwning(10L);

        when(appointmentClient.getAppointmentById(3L)).thenReturn(appointment);

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

        AppointmentSummary appointment = buildAppointment(1L, 10L, "CONFIRMED");

        authenticateAsPatientOwning(10L);

        when(paymentRepository.findById(7L)).thenReturn(Optional.of(payment));
        when(appointmentClient.getAppointmentById(1L)).thenReturn(appointment);

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

        AppointmentSummary appointment = buildAppointment(5L, 10L, "CONFIRMED");

        authenticateAsPatientOwning(10L);

        when(appointmentClient.getAppointmentById(5L)).thenReturn(appointment);
        when(paymentRepository.findByAppointmentId(5L)).thenReturn(List.of(payment));

        List<PaymentResponse> result = paymentService.getPaymentsByAppointmentId(5L);

        assertEquals(1, result.size());
        assertEquals("SIM-abc", result.get(0).getTransactionReference());
    }

    @Test
    void refundCompletedPayments_creditsWalletWithTotalAndMarksRefunded() {

        Payment completed = new Payment();
        completed.setId(1L);
        completed.setAppointmentId(5L);
        completed.setAmount(new BigDecimal("15000"));
        completed.setStatus(PaymentStatus.COMPLETED);

        authenticateAsPatientOwning(10L);
        when(appointmentClient.getAppointmentById(5L))
                .thenReturn(buildCancelledAppointment(5L, 10L, LocalDateTime.now().plusHours(72)));
        when(paymentRepository.findByAppointmentId(5L)).thenReturn(List.of(completed));
        when(paymentRepository.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        BigDecimal refunded = paymentService.refundCompletedPayments(5L, 10L);

        assertEquals(new BigDecimal("15000"), refunded);
        assertEquals(PaymentStatus.REFUNDED, completed.getStatus());
        verify(walletClient).credit(10L, 15000.0);
    }

    @Test
    void refundCompletedPayments_noCompletedPayment_doesNotCreditWallet() {

        Payment alreadyRefunded = new Payment();
        alreadyRefunded.setId(1L);
        alreadyRefunded.setAppointmentId(5L);
        alreadyRefunded.setAmount(new BigDecimal("15000"));
        alreadyRefunded.setStatus(PaymentStatus.REFUNDED);

        authenticateAsPatientOwning(10L);
        when(appointmentClient.getAppointmentById(5L))
                .thenReturn(buildCancelledAppointment(5L, 10L, LocalDateTime.now().plusHours(72)));
        when(paymentRepository.findByAppointmentId(5L)).thenReturn(List.of(alreadyRefunded));

        BigDecimal refunded = paymentService.refundCompletedPayments(5L, 10L);

        assertEquals(BigDecimal.ZERO, refunded);
        verify(walletClient, never()).credit(any(), any());
    }

    @Test
    void refundCompletedPayments_appointmentNotCancelled_throwsWithoutCrediting() {

        authenticateAsPatientOwning(10L);
        AppointmentSummary confirmed = buildCancelledAppointment(5L, 10L, LocalDateTime.now().plusHours(72));
        confirmed.setStatus("CONFIRMED");
        when(appointmentClient.getAppointmentById(5L)).thenReturn(confirmed);

        assertThrows(RuntimeException.class, () -> paymentService.refundCompletedPayments(5L, 10L));

        verify(walletClient, never()).credit(any(), any());
        verify(paymentRepository, never()).save(any());
    }

    @Test
    void refundCompletedPayments_lessThan48Hours_throwsWithoutCrediting() {

        authenticateAsPatientOwning(10L);
        when(appointmentClient.getAppointmentById(5L))
                .thenReturn(buildCancelledAppointment(5L, 10L, LocalDateTime.now().plusHours(10)));

        assertThrows(RuntimeException.class, () -> paymentService.refundCompletedPayments(5L, 10L));

        verify(walletClient, never()).credit(any(), any());
        verify(paymentRepository, never()).save(any());
    }

    @Test
    void refundCompletedPayments_otherPatientsAppointment_throwsForbidden() {

        authenticateAsPatientOwning(99L);
        when(appointmentClient.getAppointmentById(5L))
                .thenReturn(buildCancelledAppointment(5L, 10L, LocalDateTime.now().plusHours(72)));

        assertThrows(ForbiddenOperationException.class, () -> paymentService.refundCompletedPayments(5L, 10L));

        verify(walletClient, never()).credit(any(), any());
    }

    private AppointmentSummary buildCancelledAppointment(Long id, Long patientId, LocalDateTime startTime) {
        AppointmentSummary appointment = buildAppointment(id, patientId, "CANCELLED");
        appointment.setStartTime(startTime);
        return appointment;
    }
}
