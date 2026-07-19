package com.example.userservice.dto;

// REVIEWED = mesure prise, DISMISSED = signalement sans fondement
public class AdminReviewReportRequest {

    private String status;   // "REVIEWED" ou "DISMISSED"
    private String adminNote;

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getAdminNote() { return adminNote; }
    public void setAdminNote(String adminNote) { this.adminNote = adminNote; }
}
