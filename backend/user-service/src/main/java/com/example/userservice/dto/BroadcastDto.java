package com.example.userservice.dto;

import java.time.LocalDateTime;

import com.example.userservice.entity.Broadcast;

// vue publique d'un broadcast (lecture côté patient/psy)
public class BroadcastDto {

    private Long id;
    private String title;
    private String message;
    private String audience;
    private int recipientCount;
    private LocalDateTime sentAt;

    public BroadcastDto() {}

    public static BroadcastDto from(Broadcast b) {
        BroadcastDto dto = new BroadcastDto();
        dto.id             = b.getId();
        dto.title          = b.getTitle();
        dto.message        = b.getMessage();
        dto.audience       = b.getAudience();
        dto.recipientCount = b.getRecipientCount();
        dto.sentAt         = b.getSentAt();
        return dto;
    }

    public Long getId()             { return id; }
    public String getTitle()        { return title; }
    public String getMessage()      { return message; }
    public String getAudience()     { return audience; }
    public int getRecipientCount()  { return recipientCount; }
    public LocalDateTime getSentAt(){ return sentAt; }
}
