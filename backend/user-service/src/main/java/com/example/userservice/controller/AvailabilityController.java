package com.example.userservice.controller;

import com.example.userservice.dto.AvailabilityResponse;
import com.example.userservice.dto.ReplaceAvailabilitiesRequest;
import com.example.userservice.service.AvailabilityService;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/psychologists/{id}/availabilities")
public class AvailabilityController {

    private final AvailabilityService availabilityService;

    public AvailabilityController(AvailabilityService availabilityService) {
        this.availabilityService = availabilityService;
    }

    @GetMapping
    public ResponseEntity<List<AvailabilityResponse>> getAvailabilities(
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(availabilityService.getAvailabilities(id));
    }

    @PutMapping
    public ResponseEntity<List<AvailabilityResponse>> replaceAvailabilities(
            @PathVariable Long id,
            @RequestBody @Valid ReplaceAvailabilitiesRequest request,
            HttpServletRequest httpRequest
    ) {
        return ResponseEntity.ok(
                availabilityService.replaceAvailabilities(
                        id,
                        request.getAvailabilities(),
                        currentAuthUserId(httpRequest)
                )
        );
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
