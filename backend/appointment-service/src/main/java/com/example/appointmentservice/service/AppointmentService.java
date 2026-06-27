package com.example.appointmentservice.service;

import java.util.List;

import com.example.appointmentservice.dto.AppointmentResponse;
import com.example.appointmentservice.dto.CreateAppointmentRequest;
import com.example.appointmentservice.dto.RescheduleAppointmentRequest;

public interface AppointmentService {

    AppointmentResponse createAppointment(
            CreateAppointmentRequest request
    );

    AppointmentResponse getAppointmentById(
            Long id
    );

    AppointmentResponse updateAppointmentStatus(
            Long id,
            String status
    );

    /**
     * Reporte un rendez-vous encore modifiable (PENDING ou CONFIRMED) vers un
     * nouveau créneau. Réservé au patient propriétaire du rendez-vous. Un
     * rendez-vous déjà CONFIRMED repasse en PENDING : le psychologue doit
     * reconfirmer explicitement le nouveau créneau.
     */
    AppointmentResponse rescheduleAppointment(
            Long id,
            RescheduleAppointmentRequest request
    );

    List<AppointmentResponse>
getAppointmentsByPsychologistId(Long psychologistId);

List<AppointmentResponse>
getAppointmentsByPatientId(Long patientId);

/** Réservé à l'ADMIN : liste tous les rendez-vous, sans contrôle de propriété. */
List<AppointmentResponse> getAllAppointmentsForAdmin(String status);

// Supprime définitivement un rendez-vous ANNULÉ ou REFUSÉ. Réservé au
// patient propriétaire ; un PENDING/CONFIRMED/COMPLETED ne peut pas être
// supprimé.
void deleteAppointment(Long id);
}
