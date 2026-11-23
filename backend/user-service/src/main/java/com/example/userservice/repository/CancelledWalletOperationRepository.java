package com.example.userservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.userservice.entity.CancelledWalletOperation;

public interface CancelledWalletOperationRepository
        extends JpaRepository<CancelledWalletOperation, String> {
}
