package com.example.authservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

// les jetons émis avant revokedAt ne sont plus acceptés par la passerelle
@Entity
@Table(name = "access_revocations")
public class AccessRevocation {

    @Id
    private Long userId;

    @Column(nullable = false)
    private LocalDateTime revokedAt;

    public AccessRevocation() {
    }

    public AccessRevocation(Long userId, LocalDateTime revokedAt) {
        this.userId = userId;
        this.revokedAt = revokedAt;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public LocalDateTime getRevokedAt() {
        return revokedAt;
    }

    public void setRevokedAt(LocalDateTime revokedAt) {
        this.revokedAt = revokedAt;
    }
}
