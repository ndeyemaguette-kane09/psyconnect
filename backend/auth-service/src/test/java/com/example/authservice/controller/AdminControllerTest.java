package com.example.authservice.controller;

import java.time.LocalDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.test.web.servlet.MockMvc;

import com.example.authservice.dto.AdminStatsResponse;
import com.example.authservice.dto.UserAdminResponse;
import com.example.authservice.security.CustomUserDetailsService;
import com.example.authservice.security.JwtAuthenticationFilter;
import com.example.authservice.service.AdminService;

import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// pas de JWT ici, le controle ADMIN est teste ailleurs
// on verifie juste que les routes appellent bien AdminService
@WebMvcTest(AdminController.class)
@AutoConfigureMockMvc(addFilters = false)
class AdminControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AdminService adminService;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @MockBean
    private CustomUserDetailsService customUserDetailsService;

    private UserAdminResponse buildUserResponse(Long id, String role, boolean enabled) {
        UserAdminResponse response = new UserAdminResponse();
        response.setId(id);
        response.setEmail("user" + id + "@psyconnect.sn");
        response.setPseudo("user" + id);
        response.setFirstName("Prénom");
        response.setLastName("Nom");
        response.setRole(role);
        response.setEnabled(enabled);
        response.setCreatedAt(LocalDateTime.now());
        return response;
    }

    @Test
    void listUsers_returnsUserList() throws Exception {

        when(adminService.listUsers()).thenReturn(List.of(
                buildUserResponse(1L, "PATIENT", true),
                buildUserResponse(2L, "PSYCHOLOGIST", true)
        ));

        mockMvc.perform(get("/admin/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void setUserEnabled_validRequest_returnsUpdatedUser() throws Exception {

        when(adminService.setUserEnabled(eq(2L), eq(false), eq("admin@psyconnect.sn")))
                .thenReturn(buildUserResponse(2L, "PATIENT", false));

        // Avec @AutoConfigureMockMvc(addFilters = false), la chaîne de filtres
        // Spring Security (qui fait pointer request.getUserPrincipal() vers le
        // SecurityContextHolder) ne tourne pas : @WithMockUser seul ne suffit
        // donc pas à alimenter le paramètre "Authentication" du contrôleur.
        // On fixe directement le principal de la requête MockMvc.
        Authentication authentication =
                new UsernamePasswordAuthenticationToken("admin@psyconnect.sn", null);

        mockMvc.perform(patch("/admin/users/2/enabled")
                        .param("enabled", "false")
                        .principal(authentication))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(false));
    }

    @Test
    void getStats_returnsAdminStats() throws Exception {

        AdminStatsResponse stats = new AdminStatsResponse();
        stats.setTotalUsers(10);
        stats.setTotalPatients(6);
        stats.setTotalPsychologists(3);
        stats.setTotalAdmins(1);
        stats.setEnabledUsers(9);
        stats.setDisabledUsers(1);

        when(adminService.getStats()).thenReturn(stats);

        // Endpoint renommé /stats -> /stats/accounts côté AdminController
        // (routage gateway non ambigu avec les /admin/stats de user-service
        // et appointment-service) ; ce test ciblait encore l'ancien chemin.
        mockMvc.perform(get("/admin/stats/accounts"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalUsers").value(10))
                .andExpect(jsonPath("$.totalAdmins").value(1));
    }
}
