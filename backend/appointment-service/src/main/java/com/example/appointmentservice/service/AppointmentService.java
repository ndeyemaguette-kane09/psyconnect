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

    // reporte un RDV vers un nouveau creneau, le patient proprietaire only
    // Si le rendez-vous était confirmé, il repasse en attente
    AppointmentResponse rescheduleAppointment(
            Long id,
            RescheduleAppointmentRequest request
    );

    List<AppointmentResponse>
getAppointmentsByPsychologistId(Long psychologistId);

List<AppointmentResponse>
getAppointmentsByPatientId(Long patientId);

// Admin uniquement : tous les rendez-vous sans vérification de propriété
List<AppointmentResponse> getAllAppointmentsForAdmin(String status);

// appel inter-service (user-service → appointment-service) : verifie qu'un psy
// a au moins un rendez-vous avec un patient donné. Pas de vérification d'ownership :
// le contrôle de rôle est fait côté user-service avant d'appeler cet endpoint.
// requireCompleted=false → n'importe quel statut ; true → seulement COMPLETED
boolean hasAnyAppointmentBetween(Long psychologistId, Long patientId, boolean requireCompleted, boolean requireAccepted);

// suppression definitive d'un RDV annulé/refusé. patient proprietaire only,
// un PENDING/CONFIRMED/COMPLETED ne peut pas etre supprimé
void deleteAppointment(Long id);
}
