package com.example.paymentservice.repository;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.paymentservice.entity.WalletOperation;
import com.example.paymentservice.entity.WalletOperationStatus;

public interface WalletOperationRepository extends JpaRepository<WalletOperation, Long> {

    List<WalletOperation> findByStatusAndNextAttemptAtBefore(
            WalletOperationStatus status, LocalDateTime now);

    long countByStatus(WalletOperationStatus status);
}
