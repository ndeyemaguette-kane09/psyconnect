package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AdminStatsResponse {

    private long totalPatients;
    private long totalPsychologists;
    private long verifiedPsychologists;
    private long pendingPsychologists;
    private long rejectedPsychologists;
}
