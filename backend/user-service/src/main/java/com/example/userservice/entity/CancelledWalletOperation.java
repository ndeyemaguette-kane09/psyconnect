package com.example.userservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

// un débit annulé ne doit plus pouvoir être appliqué, même s'il arrive en retard
@Entity
@Table(name = "cancelled_wallet_operations")
@Getter
@Setter
public class CancelledWalletOperation {

    @Id
    private String operationKey;

    @Column(nullable = false)
    private LocalDateTime cancelledAt;

    public CancelledWalletOperation() {
    }

    public CancelledWalletOperation(String operationKey) {
        this.operationKey = operationKey;
        this.cancelledAt = LocalDateTime.now();
    }
}
