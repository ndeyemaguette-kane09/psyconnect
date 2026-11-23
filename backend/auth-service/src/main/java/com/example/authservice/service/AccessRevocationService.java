package com.example.authservice.service;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

import org.springframework.stereotype.Service;

import com.example.authservice.dto.RevocationResponse;
import com.example.authservice.entity.AccessRevocation;
import com.example.authservice.repository.AccessRevocationRepository;

@Service
public class AccessRevocationService {

    private final AccessRevocationRepository accessRevocationRepository;

    public AccessRevocationService(AccessRevocationRepository accessRevocationRepository) {
        this.accessRevocationRepository = accessRevocationRepository;
    }

    public void revoke(Long userId) {
        accessRevocationRepository.save(new AccessRevocation(userId, LocalDateTime.now()));
    }

    public List<RevocationResponse> listRevocations() {
        return accessRevocationRepository.findAll()
                .stream()
                .map(r -> new RevocationResponse(
                        r.getUserId(),
                        r.getRevokedAt().atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()))
                .toList();
    }
}
