package com.example.userservice.dto;

public class AdminResolveSupportMessageRequest {

    private String status;
    private String adminNote;

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getAdminNote() { return adminNote; }
    public void setAdminNote(String adminNote) { this.adminNote = adminNote; }
}
