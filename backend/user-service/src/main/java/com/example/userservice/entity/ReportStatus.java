package com.example.userservice.entity;

public enum ReportStatus {
    PENDING,    // en attente de traitement par l'admin
    REVIEWED,   // traité (mesure prise)
    DISMISSED   // rejeté comme non fondé
}
