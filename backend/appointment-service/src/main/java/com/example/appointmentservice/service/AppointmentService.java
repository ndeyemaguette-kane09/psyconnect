package com.example.appointmentservice.service;

import java.util.List;

import com.example.appointmentservice.dto.AppointmentResponse;
import com.example.appointmentservice.dto.CreateAppointmentRequest;
import com.example.appointmentservice.dto.RescheduleAppointmentRequest;
import com.example.appointmentservice.entity.ConsultationType;

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

    // reporte un RDV vers un nouveau creneau, le patient proprietaire only
    // Si le rendez-vous était confirmé, il repasse en attente
    AppointmentResponse rescheduleAppointment(
            Long id,
            RescheduleAppointmentRequest request
    );

    // passage en ligne <-> cabinet ; vers le cabinet, un RDV confirmé repasse en attente
    AppointmentResponse changeConsultationType(
            Long id,
            ConsultationType consultationType
    );

    List<AppointmentResponse>
getAppointmentsByPsychologistId(Long psychologistId);

List<AppointmentResponse>
getAppointmentsByPatientId(Long patientId);

// Admin uniquement : tous les rendez-vous sans vérification de propriété
List<AppointmentResponse> getAllAppointmentsForAdmin(String status);

// appelé par user-service, qui contrôle déjà le rôle avant
// requireCompleted=true : seulement les RDV COMPLETED
boolean hasAnyAppointmentBetween(Long psychologistId, Long patientId, boolean requireCompleted, boolean requireAccepted);

// suppression definitive d'un RDV annulé/refusé. patient proprietaire only,
// un PENDING/CONFIRMED/COMPLETED ne peut pas etre supprimé
void deleteAppointment(Long id);
}
