package com.example.notificationservice.entity;

import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

import jakarta.persistence.*;

@Entity
@Table(name = "notifications")
@Getter
@Setter
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;


    private Long userId;

    private String message;

    private String title;

    @Enumerated(EnumType.STRING)
private NotificationType type;


    private LocalDateTime createdAt;

    private Boolean isRead;

    @PrePersist
    public void prePersist() {
        this.createdAt = LocalDateTime.now();
    }

    public Notification() {
    }
    public Notification(Long userId, String message, String title) {
        this.userId = userId;
        this.message = message;
        this.title = title;
        this.isRead = false;
    }
    
}
