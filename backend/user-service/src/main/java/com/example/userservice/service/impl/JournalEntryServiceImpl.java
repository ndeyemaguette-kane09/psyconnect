package com.example.userservice.service.impl;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.example.userservice.dto.CreateJournalEntryRequest;
import com.example.userservice.dto.JournalEntryResponse;
import com.example.userservice.entity.JournalEntry;
import com.example.userservice.entity.PatientProfile;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.JournalEntryRepository;
import com.example.userservice.repository.PatientProfileRepository;
import com.example.userservice.service.JournalEntryService;

@Service
public class JournalEntryServiceImpl implements JournalEntryService {

    private final JournalEntryRepository journalEntryRepository;
    private final PatientProfileRepository patientProfileRepository;

    public JournalEntryServiceImpl(
            JournalEntryRepository journalEntryRepository,
            PatientProfileRepository patientProfileRepository
    ) {
        this.journalEntryRepository = journalEntryRepository;
        this.patientProfileRepository = patientProfileRepository;
    }

    @Override
    public JournalEntryResponse createEntry(
            Long authUserId,
            CreateJournalEntryRequest request
    ) {

        PatientProfile patientProfile = resolvePatientProfile(authUserId);

        JournalEntry entry = new JournalEntry();
        entry.setPatientProfile(patientProfile);
        entry.setContent(request.getContent());
        entry.setMoodRating(request.getMoodRating());

        JournalEntry saved = journalEntryRepository.save(entry);

        return mapToResponse(saved);
    }

    @Override
    public List<JournalEntryResponse> getMyEntries(Long authUserId) {

        PatientProfile patientProfile = resolvePatientProfile(authUserId);

        return journalEntryRepository
                .findByPatientProfileIdOrderByCreatedAtDesc(patientProfile.getId())
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public JournalEntryResponse getEntry(Long authUserId, Long entryId) {

        JournalEntry entry = findOwnedEntry(authUserId, entryId);

        return mapToResponse(entry);
    }

    @Override
    public JournalEntryResponse updateEntry(
            Long authUserId,
            Long entryId,
            CreateJournalEntryRequest request
    ) {

        JournalEntry entry = findOwnedEntry(authUserId, entryId);

        entry.setContent(request.getContent());
        entry.setMoodRating(request.getMoodRating());

        JournalEntry updated = journalEntryRepository.save(entry);

        return mapToResponse(updated);
    }

    @Override
    public void deleteEntry(Long authUserId, Long entryId) {

        JournalEntry entry = findOwnedEntry(authUserId, entryId);

        journalEntryRepository.delete(entry);
    }

    private PatientProfile resolvePatientProfile(Long authUserId) {

        if (authUserId == null) {
            throw new ForbiddenOperationException(
                    "Utilisateur non authentifié"
            );
        }

        return patientProfileRepository
                .findByAuthUserId(authUserId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Aucun profil patient associé à cet utilisateur"
                ));
    }

    private JournalEntry findOwnedEntry(Long authUserId, Long entryId) {

        PatientProfile patientProfile = resolvePatientProfile(authUserId);

        JournalEntry entry = journalEntryRepository.findById(entryId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Entrée de journal non trouvée"
                ));

        if (!entry.getPatientProfile().getId().equals(patientProfile.getId())) {
            throw new ForbiddenOperationException(
                    "Cette entrée de journal ne vous appartient pas"
            );
        }

        return entry;
    }

    private JournalEntryResponse mapToResponse(JournalEntry entry) {

        JournalEntryResponse response = new JournalEntryResponse();

        response.setId(entry.getId());
        response.setContent(entry.getContent());
        response.setMoodRating(entry.getMoodRating());
        response.setCreatedAt(entry.getCreatedAt());
        response.setUpdatedAt(entry.getUpdatedAt());

        return response;
    }
}
