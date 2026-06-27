package com.example.userservice.service.impl;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.example.userservice.dto.CreateJournalEntryRequest;
import com.example.userservice.dto.JournalEntryResponse;
import com.example.userservice.entity.JournalEntry;
import com.example.userservice.entity.PatientProfile;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.JournalEntryRepository;
import com.example.userservice.repository.PatientProfileRepository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class JournalEntryServiceImplTest {

    @Mock
    private JournalEntryRepository journalEntryRepository;

    @Mock
    private PatientProfileRepository patientProfileRepository;

    private JournalEntryServiceImpl journalEntryService;

    @BeforeEach
    void setUp() {
        journalEntryService = new JournalEntryServiceImpl(
                journalEntryRepository,
                patientProfileRepository
        );
    }

    private PatientProfile buildPatientProfile(Long id, Long authUserId) {
        PatientProfile profile = new PatientProfile();
        profile.setId(id);
        profile.setAuthUserId(authUserId);
        return profile;
    }

    @Test
    void createEntry_success() {

        PatientProfile profile = buildPatientProfile(1L, 100L);

        when(patientProfileRepository.findByAuthUserId(100L))
                .thenReturn(Optional.of(profile));
        when(journalEntryRepository.save(any(JournalEntry.class)))
                .thenAnswer(invocation -> {
                    JournalEntry entry = invocation.getArgument(0);
                    entry.setId(50L);
                    return entry;
                });

        CreateJournalEntryRequest request = new CreateJournalEntryRequest();
        request.setContent("Aujourd'hui était une bonne journée");
        request.setMoodRating(4);

        JournalEntryResponse response = journalEntryService.createEntry(100L, request);

        assertEquals(50L, response.getId());
        assertEquals("Aujourd'hui était une bonne journée", response.getContent());
        assertEquals(4, response.getMoodRating());
    }

    @Test
    void createEntry_noAuthUserId_throwsForbiddenAndSkipsRepository() {

        CreateJournalEntryRequest request = new CreateJournalEntryRequest();
        request.setContent("test");

        assertThrows(
                ForbiddenOperationException.class,
                () -> journalEntryService.createEntry(null, request)
        );

        verifyNoInteractions(journalEntryRepository);
    }

    @Test
    void createEntry_noPatientProfile_throwsResourceNotFound() {

        when(patientProfileRepository.findByAuthUserId(200L))
                .thenReturn(Optional.empty());

        CreateJournalEntryRequest request = new CreateJournalEntryRequest();
        request.setContent("test");

        assertThrows(
                ResourceNotFoundException.class,
                () -> journalEntryService.createEntry(200L, request)
        );
    }

    @Test
    void getMyEntries_returnsEntriesForCallersProfile() {

        PatientProfile profile = buildPatientProfile(1L, 100L);

        when(patientProfileRepository.findByAuthUserId(100L))
                .thenReturn(Optional.of(profile));

        JournalEntry entry = new JournalEntry();
        entry.setId(1L);
        entry.setPatientProfile(profile);
        entry.setContent("Entrée 1");

        when(journalEntryRepository.findByPatientProfileIdOrderByCreatedAtDesc(1L))
                .thenReturn(List.of(entry));

        List<JournalEntryResponse> entries = journalEntryService.getMyEntries(100L);

        assertEquals(1, entries.size());
        assertEquals("Entrée 1", entries.get(0).getContent());
    }

    @Test
    void getEntry_belongingToAnotherPatient_throwsForbidden() {

        PatientProfile owner = buildPatientProfile(1L, 100L);
        PatientProfile requester = buildPatientProfile(2L, 200L);

        JournalEntry entry = new JournalEntry();
        entry.setId(10L);
        entry.setPatientProfile(owner);

        when(patientProfileRepository.findByAuthUserId(200L))
                .thenReturn(Optional.of(requester));
        when(journalEntryRepository.findById(10L))
                .thenReturn(Optional.of(entry));

        assertThrows(
                ForbiddenOperationException.class,
                () -> journalEntryService.getEntry(200L, 10L)
        );
    }

    @Test
    void getEntry_notFound_throwsResourceNotFound() {

        PatientProfile profile = buildPatientProfile(1L, 100L);

        when(patientProfileRepository.findByAuthUserId(100L))
                .thenReturn(Optional.of(profile));
        when(journalEntryRepository.findById(999L))
                .thenReturn(Optional.empty());

        assertThrows(
                ResourceNotFoundException.class,
                () -> journalEntryService.getEntry(100L, 999L)
        );
    }

    @Test
    void updateEntry_ownedEntry_updatesContentAndMood() {

        PatientProfile profile = buildPatientProfile(1L, 100L);

        JournalEntry entry = new JournalEntry();
        entry.setId(10L);
        entry.setPatientProfile(profile);
        entry.setContent("ancien contenu");
        entry.setMoodRating(2);

        when(patientProfileRepository.findByAuthUserId(100L))
                .thenReturn(Optional.of(profile));
        when(journalEntryRepository.findById(10L))
                .thenReturn(Optional.of(entry));
        when(journalEntryRepository.save(any(JournalEntry.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        CreateJournalEntryRequest request = new CreateJournalEntryRequest();
        request.setContent("nouveau contenu");
        request.setMoodRating(5);

        JournalEntryResponse response = journalEntryService.updateEntry(100L, 10L, request);

        assertEquals("nouveau contenu", response.getContent());
        assertEquals(5, response.getMoodRating());
    }

    @Test
    void updateEntry_notOwned_throwsForbiddenAndDoesNotSave() {

        PatientProfile owner = buildPatientProfile(1L, 100L);
        PatientProfile requester = buildPatientProfile(2L, 200L);

        JournalEntry entry = new JournalEntry();
        entry.setId(10L);
        entry.setPatientProfile(owner);

        when(patientProfileRepository.findByAuthUserId(200L))
                .thenReturn(Optional.of(requester));
        when(journalEntryRepository.findById(10L))
                .thenReturn(Optional.of(entry));

        CreateJournalEntryRequest request = new CreateJournalEntryRequest();
        request.setContent("tentative non autorisée");

        assertThrows(
                ForbiddenOperationException.class,
                () -> journalEntryService.updateEntry(200L, 10L, request)
        );

        verify(journalEntryRepository, never()).save(any());
    }

    @Test
    void deleteEntry_ownedEntry_deletesSuccessfully() {

        PatientProfile profile = buildPatientProfile(1L, 100L);

        JournalEntry entry = new JournalEntry();
        entry.setId(10L);
        entry.setPatientProfile(profile);

        when(patientProfileRepository.findByAuthUserId(100L))
                .thenReturn(Optional.of(profile));
        when(journalEntryRepository.findById(10L))
                .thenReturn(Optional.of(entry));

        journalEntryService.deleteEntry(100L, 10L);

        verify(journalEntryRepository).delete(entry);
    }

    @Test
    void deleteEntry_notOwned_throwsForbiddenAndDoesNotDelete() {

        PatientProfile owner = buildPatientProfile(1L, 100L);
        PatientProfile requester = buildPatientProfile(2L, 200L);

        JournalEntry entry = new JournalEntry();
        entry.setId(10L);
        entry.setPatientProfile(owner);

        when(patientProfileRepository.findByAuthUserId(200L))
                .thenReturn(Optional.of(requester));
        when(journalEntryRepository.findById(10L))
                .thenReturn(Optional.of(entry));

        assertThrows(
                ForbiddenOperationException.class,
                () -> journalEntryService.deleteEntry(200L, 10L)
        );

        verify(journalEntryRepository, never()).delete(any());
    }
}
