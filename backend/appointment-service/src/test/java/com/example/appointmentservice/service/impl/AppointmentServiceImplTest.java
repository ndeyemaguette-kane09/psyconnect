package com.example.appointmentservice.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import com.example.appointmentservice.client.NotificationClient;
import com.example.appointmentservice.client.PaymentClient;
import com.example.appointmentservice.dto.AppointmentResponse;
import com.example.appointmentservice.dto.CreateAppointmentRequest;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.entity.ConsultationType;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.service.OwnershipResolver;

/**
 * Tests unitaires pour les règles métier de prise de rendez-vous.
 *
 * On utilise Mockito pour isoler AppointmentServiceImpl de ses dépendances
 * (base de données, appels inter-services). Chaque test vérifie une règle
 * précise, indépendamment des autres.
 */
@ExtendWith(MockitoExtension.class)
class AppointmentServiceImplTest {

    @Mock AppointmentRepository appointmentRepository;
    @Mock NotificationClient     notificationClient;
    @Mock OwnershipResolver      ownershipResolver;
    @Mock PaymentClient          paymentClient;

    @InjectMocks AppointmentServiceImpl service;

    // Le patient fictif utilisé dans tous les tests
    private static final Long PATIENT_ID      = 1L;
    private static final Long PSYCHOLOGIST_ID = 2L;

    /**
     * Simule une authentification PATIENT dans le SecurityContext Spring.
     * SecurityUtils.hasRole() lit directement SecurityContextHolder,
     * donc pas besoin de mock statique.
     */
    @BeforeEach
    void authenticateAsPatient() {
        var auth = new UsernamePasswordAuthenticationToken(
                String.valueOf(PATIENT_ID),
                null,
                List.of(new SimpleGrantedAuthority("ROLE_PATIENT"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    // --- Helpers ---

    private CreateAppointmentRequest buildRequest() {
        LocalDateTime start = LocalDateTime.now().plusDays(1);
        CreateAppointmentRequest req = new CreateAppointmentRequest();
        req.setPatientId(PATIENT_ID);
        req.setPsychologistId(PSYCHOLOGIST_ID);
        req.setStartTime(start);
        req.setEndTime(start.plusHours(1));
        req.setConsultationType(ConsultationType.VIDEO);
        return req;
    }

    // --- Tests double-réservation psy ---

    @Test
    @DisplayName("Créneau psy occupé (RDV actif) → exception")
    void createAppointment_whenPsychologistSlotTaken_throwsException() {
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);
        when(ownershipResolver.isPsychologistVerified(PSYCHOLOGIST_ID)).thenReturn(true);

        // Le psy a déjà un RDV actif sur ce créneau
        when(appointmentRepository
                .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        eq(PSYCHOLOGIST_ID), any(), any(), anyCollection()))
                .thenReturn(true);

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> service.createAppointment(buildRequest()));

        assertTrue(ex.getMessage().contains("psychologue"));
    }

    @Test
    @DisplayName("Créneau psy libre → pas d'exception levée pour le psy")
    void createAppointment_whenPsychologistSlotFree_proceedsToPatientCheck() {
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);
        when(ownershipResolver.isPsychologistVerified(PSYCHOLOGIST_ID)).thenReturn(true);

        // Psy libre, patient occupé → l'exception doit parler du patient
        when(appointmentRepository
                .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        anyLong(), any(), any(), anyCollection()))
                .thenReturn(false);

        when(appointmentRepository
                .existsByPatientIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        anyLong(), any(), any(), anyCollection()))
                .thenReturn(true);

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> service.createAppointment(buildRequest()));

        assertTrue(ex.getMessage().toLowerCase().contains("vous avez déjà"));
    }

    // --- Tests double-réservation patient ---

    @Test
    @DisplayName("Patient a déjà un RDV actif sur ce créneau → exception")
    void createAppointment_whenPatientSlotTaken_throwsException() {
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);
        when(ownershipResolver.isPsychologistVerified(PSYCHOLOGIST_ID)).thenReturn(true);

        when(appointmentRepository
                .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        anyLong(), any(), any(), anyCollection()))
                .thenReturn(false);

        when(appointmentRepository
                .existsByPatientIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        eq(PATIENT_ID), any(), any(), anyCollection()))
                .thenReturn(true);

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> service.createAppointment(buildRequest()));

        assertTrue(ex.getMessage().contains("Vous avez déjà"));
    }

    @Test
    @DisplayName("Créneau libre pour les deux → RDV créé avec succès")
    void createAppointment_whenNoConflict_createsAppointment() {
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);
        when(ownershipResolver.isPsychologistVerified(PSYCHOLOGIST_ID)).thenReturn(true);

        when(appointmentRepository
                .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        anyLong(), any(), any(), anyCollection()))
                .thenReturn(false);

        when(appointmentRepository
                .existsByPatientIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        anyLong(), any(), any(), anyCollection()))
                .thenReturn(false);

        // Mock save : renvoie un Appointment factice
        var saved = new com.example.appointmentservice.entity.Appointment();
        saved.setId(99L);
        saved.setPatientId(PATIENT_ID);
        saved.setPsychologistId(PSYCHOLOGIST_ID);
        saved.setStartTime(LocalDateTime.now().plusDays(1));
        saved.setEndTime(LocalDateTime.now().plusDays(1).plusHours(1));
        saved.setConsultationType(ConsultationType.VIDEO);
        saved.setStatus(AppointmentStatus.PENDING);
        when(appointmentRepository.save(any())).thenReturn(saved);

        // Pas besoin de vérifier le résultat en détail : si aucune exception
        // n'est levée, la règle métier est respectée
        AppointmentResponse response = service.createAppointment(buildRequest());

        assertNotNull(response);
        assertEquals(AppointmentStatus.PENDING, response.getStatus());
        verify(appointmentRepository).save(any());
    }

    // --- Validation basique ---

    @Test
    @DisplayName("Date de fin avant date de début → exception")
    void createAppointment_whenEndBeforeStart_throwsException() {
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);

        CreateAppointmentRequest req = buildRequest();
        req.setEndTime(req.getStartTime().minusHours(1)); // fin avant début

        assertThrows(RuntimeException.class, () -> service.createAppointment(req));
    }

    @Test
    @DisplayName("Créneau dans le passé → exception")
    void createAppointment_whenStartInPast_throwsException() {
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);

        CreateAppointmentRequest req = buildRequest();
        req.setStartTime(LocalDateTime.now().minusDays(1));
        req.setEndTime(LocalDateTime.now().minusHours(23));

        assertThrows(RuntimeException.class, () -> service.createAppointment(req));
    }
}
