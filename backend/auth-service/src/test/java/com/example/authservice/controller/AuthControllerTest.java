package com.example.authservice.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.ObjectMapper;

import com.example.authservice.dto.AuthResponse;
import com.example.authservice.dto.LoginRequest;
import com.example.authservice.dto.MessageResponse;
import com.example.authservice.dto.RegisterRequest;
import com.example.authservice.entity.Role;
import com.example.authservice.security.CustomUserDetailsService;
import com.example.authservice.security.JwtAuthenticationFilter;
import com.example.authservice.service.AuthService;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// La chaîne de filtres de sécurité (JWT) est désactivée ici : on teste
// uniquement la logique du contrôleur. JwtAuthenticationFilter et
// CustomUserDetailsService sont mockés pour permettre à Spring de
// construire le contexte @WebMvcTest sans erreur (ils ne sont pas
// auto-détectés comme des beans simples par le slice de test).
@WebMvcTest(AuthController.class)
@AutoConfigureMockMvc(addFilters = false)
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private AuthService authService;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @MockBean
    private CustomUserDetailsService customUserDetailsService;

    @Test
    void register_validRequest_returnsOk() throws Exception {

        RegisterRequest request = new RegisterRequest();
        request.setEmail("patient@psyconnect.sn");
        request.setPassword("password123");
        request.setPseudo("patient1");
        request.setFirstName("Awa");
        request.setLastName("Diop");
        request.setRole(Role.PATIENT);

        when(authService.register(any(RegisterRequest.class)))
                .thenReturn(new MessageResponse("User registered successfully"));

        mockMvc.perform(post("/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("User registered successfully"));
    }

    @Test
    void registerPatient_forcesPatientRole() throws Exception {

        RegisterRequest request = new RegisterRequest();
        request.setEmail("patient@psyconnect.sn");
        request.setPassword("password123");
        request.setPseudo("patient1");
        request.setFirstName("Awa");
        request.setLastName("Diop");

        when(authService.register(any(RegisterRequest.class)))
                .thenReturn(new MessageResponse("User registered successfully"));

        mockMvc.perform(post("/auth/register/patient")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    @Test
    void login_validCredentials_returnsToken() throws Exception {

        LoginRequest request = new LoginRequest();
        request.setEmail("patient@psyconnect.sn");
        request.setPassword("password123");

        AuthResponse response = new AuthResponse("fake-jwt-token", "PATIENT", 1L, "patient1");

        when(authService.login(any(LoginRequest.class))).thenReturn(response);

        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("fake-jwt-token"))
                .andExpect(jsonPath("$.role").value("PATIENT"));
    }

    @Test
    void me_authenticatedUser_returnsCurrentUser() throws Exception {

        AuthResponse response = new AuthResponse(null, "PATIENT", 1L, "patient1");

        when(authService.getCurrentUser(eq("patient@psyconnect.sn"))).thenReturn(response);

        // Voir le commentaire équivalent dans AdminControllerTest : avec les
        // filtres désactivés, @WithMockUser ne suffit pas à alimenter le
        // paramètre "Authentication" du contrôleur ; on fixe le principal
        // directement sur la requête MockMvc.
        Authentication authentication =
                new UsernamePasswordAuthenticationToken("patient@psyconnect.sn", null);

        mockMvc.perform(get("/auth/me").principal(authentication))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pseudo").value("patient1"));
    }
}
