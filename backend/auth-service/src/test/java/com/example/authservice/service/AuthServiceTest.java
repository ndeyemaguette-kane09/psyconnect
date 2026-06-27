package com.example.authservice.service;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.example.authservice.dto.AuthResponse;
import com.example.authservice.dto.LoginRequest;
import com.example.authservice.dto.MessageResponse;
import com.example.authservice.dto.RegisterRequest;
import com.example.authservice.entity.Role;
import com.example.authservice.entity.User;
import com.example.authservice.repository.UserRepository;
import com.example.authservice.security.JwtService;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordEncoder, jwtService);
    }

    private RegisterRequest buildRegisterRequest(Role role) {
        RegisterRequest request = new RegisterRequest();
        request.setEmail("patient@psyconnect.sn");
        request.setPassword("password123");
        request.setPseudo("patient1");
        request.setFirstName("Awa");
        request.setLastName("Diop");
        request.setRole(role);
        return request;
    }

    private User buildUser(Long id, String email, String pseudo, Role role, boolean enabled) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        user.setPassword("encodedPassword");
        user.setPseudo(pseudo);
        user.setRole(role);
        user.setFirstName("Awa");
        user.setLastName("Diop");
        user.setEnabled(enabled);
        return user;
    }

    // --- register ---

    @Test
    void register_validPatientRequest_savesUserAndReturnsMessage() {

        RegisterRequest request = buildRegisterRequest(Role.PATIENT);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        when(userRepository.findByPseudo(request.getPseudo())).thenReturn(Optional.empty());
        when(passwordEncoder.encode(request.getPassword())).thenReturn("encodedPassword");

        MessageResponse response = authService.register(request);

        assertEquals("User registered successfully", response.getMessage());
        verify(userRepository).save(any(User.class));
    }

    @Test
    void register_emailAlreadyExists_throwsAndDoesNotSave() {

        RegisterRequest request = buildRegisterRequest(Role.PATIENT);

        when(userRepository.findByEmail(request.getEmail()))
                .thenReturn(Optional.of(buildUser(1L, request.getEmail(), "other", Role.PATIENT, true)));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));

        assertEquals("Email already exists", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void register_pseudoAlreadyExists_throwsAndDoesNotSave() {

        RegisterRequest request = buildRegisterRequest(Role.PATIENT);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        when(userRepository.findByPseudo(request.getPseudo()))
                .thenReturn(Optional.of(buildUser(1L, "other@psyconnect.sn", request.getPseudo(), Role.PATIENT, true)));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));

        assertEquals("Pseudo already exists", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void register_missingRole_throwsAndDoesNotSave() {

        RegisterRequest request = buildRegisterRequest(null);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        when(userRepository.findByPseudo(request.getPseudo())).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));

        assertEquals("Role is required", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void register_roleAdmin_isBlocked() {

        RegisterRequest request = buildRegisterRequest(Role.ADMIN);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        when(userRepository.findByPseudo(request.getPseudo())).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));

        assertEquals("Cannot register as admin", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

    // --- login ---

    @Test
    void login_validCredentials_returnsTokenAndRole() {

        LoginRequest request = new LoginRequest();
        request.setEmail("patient@psyconnect.sn");
        request.setPassword("password123");

        User user = buildUser(1L, request.getEmail(), "patient1", Role.PATIENT, true);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(request.getPassword(), user.getPassword())).thenReturn(true);
        when(jwtService.generateToken(anyString(), anyString(), anyLong())).thenReturn("fake-jwt-token");

        AuthResponse response = authService.login(request);

        assertEquals("fake-jwt-token", response.getToken());
        assertEquals("PATIENT", response.getRole());
        assertEquals(1L, response.getUserId());
        assertEquals("patient1", response.getPseudo());
    }

    @Test
    void login_userNotFound_throws() {

        LoginRequest request = new LoginRequest();
        request.setEmail("inconnu@psyconnect.sn");
        request.setPassword("password123");

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.login(request));

        assertEquals("User not found", ex.getMessage());
    }

    @Test
    void login_disabledAccount_throws() {

        LoginRequest request = new LoginRequest();
        request.setEmail("patient@psyconnect.sn");
        request.setPassword("password123");

        User user = buildUser(1L, request.getEmail(), "patient1", Role.PATIENT, false);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.of(user));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.login(request));

        assertEquals("User account is disabled", ex.getMessage());
    }

    @Test
    void login_wrongPassword_throws() {

        LoginRequest request = new LoginRequest();
        request.setEmail("patient@psyconnect.sn");
        request.setPassword("wrongPassword");

        User user = buildUser(1L, request.getEmail(), "patient1", Role.PATIENT, true);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(request.getPassword(), user.getPassword())).thenReturn(false);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.login(request));

        assertEquals("Invalid password", ex.getMessage());
    }

    // --- getCurrentUser ---

    @Test
    void getCurrentUser_existingEmail_returnsResponseWithoutToken() {

        User user = buildUser(1L, "patient@psyconnect.sn", "patient1", Role.PATIENT, true);

        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));

        AuthResponse response = authService.getCurrentUser(user.getEmail());

        assertEquals(null, response.getToken());
        assertEquals("PATIENT", response.getRole());
        assertEquals(1L, response.getUserId());
        assertEquals("patient1", response.getPseudo());
    }

    @Test
    void getCurrentUser_unknownEmail_throws() {

        when(userRepository.findByEmail("inconnu@psyconnect.sn")).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> authService.getCurrentUser("inconnu@psyconnect.sn"));

        assertEquals("User not found", ex.getMessage());
    }
}
