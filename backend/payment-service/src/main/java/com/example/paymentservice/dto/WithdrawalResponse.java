package com.example.paymentservice.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.fasterxml.jackson.annotation.JsonFormat;

public class WithdrawalResponse {

    private Long id;
    private Long psychologistId;
    private BigDecimal amount;
    private String method;
    private String status;

    // évite les nanosecondes (9 chiffres) que Dart ne peut pas parser
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getPsychologistId() { return psychologistId; }
    public void setPsychologistId(Long psychologistId) { this.psychologistId = psychologistId; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getMethod() { return method; }
    public void setMethod(String method) { this.method = method; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
