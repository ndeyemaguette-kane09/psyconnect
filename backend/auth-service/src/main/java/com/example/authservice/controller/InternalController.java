package com.example.authservice.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.authservice.dto.RevocationResponse;
import com.example.authservice.service.AccessRevocationService;

// lu par la passerelle uniquement : aucune route publique ne mène à /internal
@RestController
@RequestMapping("/internal")
public class InternalController {

    private final AccessRevocationService accessRevocationService;

    public InternalController(AccessRevocationService accessRevocationService) {
        this.accessRevocationService = accessRevocationService;
    }

    @GetMapping("/revocations")
    public ResponseEntity<List<RevocationResponse>> listRevocations() {
        return ResponseEntity.ok(accessRevocationService.listRevocations());
    }
}
