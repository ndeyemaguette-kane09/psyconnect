package com.example.userservice.service;

import java.util.List;

import com.example.userservice.dto.CreateJournalEntryRequest;
import com.example.userservice.dto.JournalEntryResponse;

public interface JournalEntryService {

    JournalEntryResponse createEntry(Long authUserId, CreateJournalEntryRequest request);

    List<JournalEntryResponse> getMyEntries(Long authUserId);

    JournalEntryResponse getEntry(Long authUserId, Long entryId);

    JournalEntryResponse updateEntry(Long authUserId, Long entryId, CreateJournalEntryRequest request);

    void deleteEntry(Long authUserId, Long entryId);
}
