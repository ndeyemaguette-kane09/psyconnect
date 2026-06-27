package com.example.appointmentservice.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.appointmentservice.entity.Payment;
import com.example.appointmentservice.entity.PaymentStatus;

public interface PaymentRepository
        extends JpaRepository<Payment, Long> {

    List<Payment> findByAppointmentId(Long appointmentId);

    long countByStatus(PaymentStatus status);

    List<Payment> findByStatus(PaymentStatus status);

    /**
     * Utilisé pour le revenu d'un psychologue (cf. PaymentController) : les
     * paiements n'ont pas de psychologistId direct, on filtre donc par la
     * liste des appointmentId de ce psychologue (AppointmentRepository
     * #findByPsychologistId), puis par statut COMPLETED.
     */
    List<Payment> findByAppointmentIdInAndStatus(
            List<Long> appointmentIds,
            PaymentStatus status
    );
}
