package com.example.authservice.dto;

public record RevocationResponse(Long userId, long revokedAt) {
}
