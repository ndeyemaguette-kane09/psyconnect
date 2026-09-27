package com.example.userservice.service.impl;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.example.userservice.client.AppointmentClient;
import com.example.userservice.entity.PsyPatientLink;
import com.example.userservice.entity.PsychologistProfile;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.repository.PatientProfileRepository;
import com.example.userservice.repository.PsyPatientLinkRepository;
import com.example.userservice.repository.PsychologistProfileRepository;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PsyPatientLinkServiceImplTest {

    @Mock
    private PsyPatientLinkRepository linkRepository;

    @Mock
    private PsychologistProfileRepository psychologistRepository;

    @Mock
    private PatientProfileRepository patientRepository;

    @Mock
    private AppointmentClient appointmentClient;

    private PsyPatientLinkServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new PsyPatientLinkServiceImpl(
                linkRepository,
                psychologistRepository,
                patientRepository,
                appointmentClient
        );
        PsychologistProfile psy = new PsychologistProfile();
        psy.setId(10L);
        psy.setAuthUserId(200L);
        when(psychologistRepository.findByAuthUserId(200L)).thenReturn(Optional.of(psy));
        when(patientRepository.existsById(1L)).thenReturn(true);
    }

    @Test
    void addFollowedPatient_refusedWithoutAcceptedAppointment() {
        when(linkRepository.existsByPsychologistProfileIdAndPatientProfileId(10L, 1L)).thenReturn(false);
        when(appointmentClient.hasAcceptedAppointmentBetween(10L, 1L)).thenReturn(false);

        assertThrows(ForbiddenOperationException.class,
                () -> service.addFollowedPatient(10L, 1L, 200L));

        verify(linkRepository, never()).save(any(PsyPatientLink.class));
    }

    @Test
    void addFollowedPatient_allowedAfterAcceptedAppointment() {
        when(linkRepository.existsByPsychologistProfileIdAndPatientProfileId(10L, 1L)).thenReturn(false);
        when(appointmentClient.hasAcceptedAppointmentBetween(10L, 1L)).thenReturn(true);

        service.addFollowedPatient(10L, 1L, 200L);

        verify(linkRepository).save(any(PsyPatientLink.class));
    }

    @Test
    void addFollowedPatient_existingLinkDoesNotCallAppointmentService() {
        when(linkRepository.existsByPsychologistProfileIdAndPatientProfileId(10L, 1L)).thenReturn(true);

        service.addFollowedPatient(10L, 1L, 200L);

        verifyNoInteractions(appointmentClient);
        verify(linkRepository, never()).save(any(PsyPatientLink.class));
    }
}
