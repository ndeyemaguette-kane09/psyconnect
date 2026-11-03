package com.example.userservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

// annonce admin gardée en base pour GET /broadcasts,
// lisible même si notification-service est down
@Entity
@Getter
@Setter
@Table(name = "broadcasts")
public class Broadcast {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String message;

    // ALL | PATIENTS | PSYCHOLOGISTS
    @Column(nullable = false)
    private String audience;

    // nombre estimé de destinataires au moment de l'envoi
    private int recipientCount;

    // date/heure d'envoi (injectée par @PrePersist)
    private LocalDateTime sentAt;

    @PrePersist
    protected void onCreate() {
        this.sentAt = LocalDateTime.now();
    }

    public Broadcast() {}
}
