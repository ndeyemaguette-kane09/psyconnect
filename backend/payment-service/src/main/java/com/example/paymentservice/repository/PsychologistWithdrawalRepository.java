package com.example.paymentservice.repository;

import com.example.paymentservice.entity.PsychologistWithdrawal;
import org.springframework.data.jpa.repository.JpaRepository;

import java.math.BigDecimal;
import java.util.List;

public interface PsychologistWithdrawalRepository
        extends JpaRepository<PsychologistWithdrawal, Long> {

    List<PsychologistWithdrawal> findByPsychologistIdOrderByCreatedAtDesc(
            Long psychologistId);

    // somme directe en DB plutot que de tout charger en memoire
    default BigDecimal sumWithdrawn(Long psychologistId) {
        return findByPsychologistIdOrderByCreatedAtDesc(psychologistId)
                .stream()
                .map(PsychologistWithdrawal::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
