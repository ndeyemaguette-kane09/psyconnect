package com.example.userservice.controller;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.ObjectMapper;

import com.example.userservice.dto.CreateJournalEntryRequest;
import com.example.userservice.dto.JournalEntryResponse;
import com.example.userservice.security.JwtAuthenticationFilter;
import com.example.userservice.service.JournalEntryService;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// on coupe la securite ici, on teste juste le controleur
// on simule direct l'attribut "authUserId" mis par le filtre JWT
@WebMvcTest(JournalEntryController.class)
@AutoConfigureMockMvc(addFilters = false)
class JournalEntryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private JournalEntryService journalEntryService;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Test
    void createEntry_withAuthUserId_returnsCreated() throws Exception {

        CreateJournalEntryRequest request = new CreateJournalEntryRequest();
        request.setContent("Première entrée");
        request.setMoodRating(3);

        JournalEntryResponse response = new JournalEntryResponse();
        response.setId(1L);
        response.setContent("Première entrée");
        response.setMoodRating(3);

        when(journalEntryService.createEntry(eq(42L), any(CreateJournalEntryRequest.class)))
                .thenReturn(response);

        mockMvc.perform(post("/journal")
                        .requestAttr("authUserId", 42L)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.content").value("Première entrée"));
    }

    @Test
    void createEntry_blankContent_returnsBadRequest() throws Exception {

        mockMvc.perform(post("/journal")
                        .requestAttr("authUserId", 42L)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void getMyEntries_returnsList() throws Exception {

        JournalEntryResponse response = new JournalEntryResponse();
        response.setId(1L);
        response.setContent("Entrée");

        when(journalEntryService.getMyEntries(42L)).thenReturn(List.of(response));

        mockMvc.perform(get("/journal").requestAttr("authUserId", 42L))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].content").value("Entrée"));
    }

    @Test
    void getEntry_returnsOk() throws Exception {

        JournalEntryResponse response = new JournalEntryResponse();
        response.setId(5L);
        response.setContent("Entrée précise");

        when(journalEntryService.getEntry(42L, 5L)).thenReturn(response);

        mockMvc.perform(get("/journal/5").requestAttr("authUserId", 42L))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(5));
    }

    @Test
    void deleteEntry_returnsNoContent() throws Exception {

        mockMvc.perform(delete("/journal/5").requestAttr("authUserId", 42L))
                .andExpect(status().isNoContent());
    }
}
