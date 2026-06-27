package com.example.userservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class JournalEntryResponse {

    private Long id;
    private String content;
    private Integer moodRating;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
