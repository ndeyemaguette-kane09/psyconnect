package com.example.authservice.service.impl;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.example.authservice.dto.AdminStatsResponse;
import com.example.authservice.dto.UserAdminResponse;
import com.example.authservice.entity.Role;
import com.example.authservice.entity.User;
import com.example.authservice.repository.UserRepository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminServiceImplTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    private AdminServiceImpl adminService;

    @BeforeEach
    void setUp() {
        adminService = new AdminServiceImpl(userRepository, passwordEncoder);
    }

    private User buildUser(Long id, String email, Role role, boolean enabled) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        user.setPseudo("user" + id);
        user.setRole(role);
        user.setFirstName("Prénom");
        user.setLastName("Nom");
        user.setEnabled(enabled);
        return user;
    }

    @Test
    void listUsers_returnsAllUsersMapped() {

        when(userRepository.findAll()).thenReturn(List.of(
                buildUser(1L, "patient@psyconnect.sn", Role.PATIENT, true),
                buildUser(2L, "psy@psyconnect.sn", Role.PSYCHOLOGIST, true)
        ));

        List<UserAdminResponse> result = adminService.listUsers();

        assertEquals(2, result.size());
        assertEquals("PATIENT", result.get(0).getRole());
        assertEquals("PSYCHOLOGIST", result.get(1).getRole());
    }

    @Test
    void setUserEnabled_validTarget_disablesAccount() {

        User target = buildUser(2L, "patient@psyconnect.sn", Role.PATIENT, true);

        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        UserAdminResponse response = adminService.setUserEnabled(2L, false, "admin@psyconnect.sn");

        assertEquals(false, response.isEnabled());
        verify(userRepository).save(target);
    }

    @Test
    void setUserEnabled_targetIsAdmin_throwsAndDoesNotSave() {

        User target = buildUser(3L, "autre-admin@psyconnect.sn", Role.ADMIN, true);

        when(userRepository.findById(3L)).thenReturn(Optional.of(target));

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> adminService.setUserEnabled(3L, false, "admin@psyconnect.sn"));

        assertEquals("Impossible d'activer/désactiver un compte administrateur", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void setUserEnabled_targetIsCallerSelf_throwsAndDoesNotSave() {

        User caller = buildUser(1L, "patient@psyconnect.sn", Role.PATIENT, true);

        when(userRepository.findById(1L)).thenReturn(Optional.of(caller));

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> adminService.setUserEnabled(1L, false, "patient@psyconnect.sn"));

        assertEquals("Vous ne pouvez pas modifier votre propre compte", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void setUserEnabled_userNotFound_throws() {

        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> adminService.setUserEnabled(99L, false, "admin@psyconnect.sn"));

        assertEquals("Utilisateur non trouvé", ex.getMessage());
    }

    @Test
    void deleteUser_validTarget_deletesAccount() {

        User target = buildUser(2L, "patient@psyconnect.sn", Role.PATIENT, true);

        when(userRepository.findById(2L)).thenReturn(Optional.of(target));

        adminService.deleteUser(2L, "admin@psyconnect.sn");

        verify(userRepository).delete(target);
    }

    @Test
    void deleteUser_targetIsAdmin_throwsAndDoesNotDelete() {

        User target = buildUser(3L, "autre-admin@psyconnect.sn", Role.ADMIN, true);

        when(userRepository.findById(3L)).thenReturn(Optional.of(target));

        assertThrows(RuntimeException.class,
                () -> adminService.deleteUser(3L, "admin@psyconnect.sn"));

        verify(userRepository, never()).delete(any(User.class));
    }

    @Test
    void deleteUser_targetIsCallerSelf_throwsAndDoesNotDelete() {

        User caller = buildUser(1L, "patient@psyconnect.sn", Role.PATIENT, true);

        when(userRepository.findById(1L)).thenReturn(Optional.of(caller));

        assertThrows(RuntimeException.class,
                () -> adminService.deleteUser(1L, "patient@psyconnect.sn"));

        verify(userRepository, never()).delete(any(User.class));
    }

    @Test
    void resetPassword_validTarget_encodesAndSavesNewPassword() {

        User target = buildUser(2L, "patient@psyconnect.sn", Role.PATIENT, true);

        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(passwordEncoder.encode("NouveauMdp123")).thenReturn("ENCODED");
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        UserAdminResponse response = adminService.resetPassword(2L, "NouveauMdp123", "admin@psyconnect.sn");

        assertEquals(2L, response.getId());
        assertEquals("ENCODED", target.getPassword());
        verify(userRepository).save(target);
    }

    @Test
    void resetPassword_targetIsAdmin_throwsAndDoesNotSave() {

        User target = buildUser(3L, "autre-admin@psyconnect.sn", Role.ADMIN, true);

        when(userRepository.findById(3L)).thenReturn(Optional.of(target));

        assertThrows(RuntimeException.class,
                () -> adminService.resetPassword(3L, "NouveauMdp123", "admin@psyconnect.sn"));

        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void getStats_returnsCountsFromRepository() {

        when(userRepository.count()).thenReturn(10L);
        when(userRepository.countByRole(Role.PATIENT)).thenReturn(6L);
        when(userRepository.countByRole(Role.PSYCHOLOGIST)).thenReturn(3L);
        when(userRepository.countByRole(Role.ADMIN)).thenReturn(1L);
        when(userRepository.countByEnabled(true)).thenReturn(9L);
        when(userRepository.countByEnabled(false)).thenReturn(1L);

        AdminStatsResponse stats = adminService.getStats();

        assertEquals(10L, stats.getTotalUsers());
        assertEquals(6L, stats.getTotalPatients());
        assertEquals(3L, stats.getTotalPsychologists());
        assertEquals(1L, stats.getTotalAdmins());
        assertEquals(9L, stats.getEnabledUsers());
        assertEquals(1L, stats.getDisabledUsers());
    }
}
