package com.example.userservice.controller;

import java.util.List;

import com.example.userservice.dto.CreateJournalEntryRequest;
import com.example.userservice.dto.JournalEntryResponse;
import com.example.userservice.service.JournalEntryService;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/journal")
public class JournalEntryController {

    private final JournalEntryService journalEntryService;

    public JournalEntryController(JournalEntryService journalEntryService) {
        this.journalEntryService = journalEntryService;
    }

    @PostMapping
    public ResponseEntity<JournalEntryResponse> createEntry(
            HttpServletRequest httpRequest,
            @Valid @RequestBody CreateJournalEntryRequest request
    ) {

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(
                        journalEntryService.createEntry(
                                currentAuthUserId(httpRequest),
                                request
                        )
                );
    }

    @GetMapping
    public ResponseEntity<List<JournalEntryResponse>> getMyEntries(
            HttpServletRequest httpRequest
    ) {

        return ResponseEntity.ok(
                journalEntryService.getMyEntries(
                        currentAuthUserId(httpRequest)
                )
        );
    }

    @GetMapping("/{id}")
    public ResponseEntity<JournalEntryResponse> getEntry(
            HttpServletRequest httpRequest,
            @PathVariable Long id
    ) {

        return ResponseEntity.ok(
                journalEntryService.getEntry(
                        currentAuthUserId(httpRequest),
                        id
                )
        );
    }

    @PutMapping("/{id}")
    public ResponseEntity<JournalEntryResponse> updateEntry(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @Valid @RequestBody CreateJournalEntryRequest request
    ) {

        return ResponseEntity.ok(
                journalEntryService.updateEntry(
                        currentAuthUserId(httpRequest),
                        id,
                        request
                )
        );
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEntry(
            HttpServletRequest httpRequest,
            @PathVariable Long id
    ) {

        journalEntryService.deleteEntry(
                currentAuthUserId(httpRequest),
                id
        );

        return ResponseEntity.noContent().build();
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
