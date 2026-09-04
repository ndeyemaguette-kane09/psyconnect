package com.example.userservice.dto;

public class CreateSupportMessageRequest {

    private String subject;
    private String message;

    public String getSubject() { return subject; }
    public void setSubject(String subject) { this.subject = subject; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
}
