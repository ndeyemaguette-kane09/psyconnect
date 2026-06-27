package com.example.appointmentservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;


@Entity
@Table(name = "appointments")
@Getter
@Setter
public class Appointment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long patientId;
    @Column(nullable = false)
    private Long psychologistId;

    
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime startTime;
    @Column(nullable = false)
    private LocalDateTime endTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AppointmentStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ConsultationType consultationType;


    private String notes;
    
    private String meetingLink;

    // Rappel automatique 1h avant le rendez-vous (AppointmentReminderScheduler) :
    // évite d'envoyer le même rappel plusieurs fois au fil des passages du
    // job planifié. `columnDefinition` pour que les rendez-vous déjà en base
    // avant cette colonne ne se retrouvent pas avec une valeur NULL (qui
    // empêcherait le filtre ...ReminderSentFalse de les sélectionner).
    @Column(columnDefinition = "boolean default false")
    private Boolean reminderSent = Boolean.FALSE;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    public Appointment() {
    }
    
}
