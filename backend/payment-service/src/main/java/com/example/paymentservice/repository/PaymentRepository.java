package com.example.paymentservice.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.paymentservice.entity.Payment;
import com.example.paymentservice.entity.PaymentStatus;

public interface PaymentRepository extends JpaRepository<Payment, Long> {

    List<Payment> findByAppointmentId(Long appointmentId);

    long countByStatus(PaymentStatus status);

    List<Payment> findByStatus(PaymentStatus status);

    List<Payment> findByAppointmentIdInAndStatus(List<Long> appointmentIds, PaymentStatus status);

    // tous statuts confondus pour l'historique des transactions (completed + refunded)
    List<Payment> findByAppointmentIdIn(List<Long> appointmentIds);

    // requêtes directes par psychologistId, évitent tout appel vers appointment-service
    List<Payment> findByPsychologistIdAndStatus(Long psychologistId, PaymentStatus status);

    List<Payment> findByPsychologistId(Long psychologistId);
}
