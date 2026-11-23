package com.example.userservice.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.userservice.entity.WalletTransaction;

public interface WalletTransactionRepository extends JpaRepository<WalletTransaction, Long> {

    List<WalletTransaction> findByPatientProfileIdOrderByCreatedAtDesc(Long patientProfileId);

    Optional<WalletTransaction> findByOperationKey(String operationKey);

    boolean existsByOperationKey(String operationKey);
}
