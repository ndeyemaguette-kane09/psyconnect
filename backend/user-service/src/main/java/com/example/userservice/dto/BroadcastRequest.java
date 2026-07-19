package com.example.userservice.dto;

// corps de POST /admin/notifications/broadcast
// audience : "ALL" → tous les profils (patients + psys)
//            "PATIENTS" → patients uniquement
//            "PSYCHOLOGISTS" → psychologues uniquement
public class BroadcastRequest {

    private String title;
    private String message;
    private String audience; // ALL | PATIENTS | PSYCHOLOGISTS

    public BroadcastRequest() {}

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public String getAudience() { return audience; }
    public void setAudience(String audience) { this.audience = audience; }
}
