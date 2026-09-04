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
import com.example.authservice.repository.PasswordResetCodeRepository;
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

    @Mock
    private PasswordResetCodeRepository passwordResetCodeRepository;

    @Mock
    private PasswordResetMailer passwordResetMailer;

    @Mock
    private ResetRequestThrottle resetRequestThrottle;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(
                userRepository,
                passwordResetCodeRepository,
                passwordEncoder,
                jwtService,
                passwordResetMailer,
                resetRequestThrottle
        );
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

    @Test
    void register_validPatientRequest_savesUserAndReturnsMessage() {

        RegisterRequest request = buildRegisterRequest(Role.PATIENT);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        when(userRepository.findByPseudo(request.getPseudo())).thenReturn(Optional.empty());
        when(passwordEncoder.encode(request.getPassword())).thenReturn("encodedPassword");

        MessageResponse response = authService.register(request);

        assertEquals("Inscription réussie", response.getMessage());
        verify(userRepository).save(any(User.class));
    }

    @Test
    void register_emailAlreadyExists_throwsAndDoesNotSave() {

        RegisterRequest request = buildRegisterRequest(Role.PATIENT);

        when(userRepository.findByEmail(request.getEmail()))
                .thenReturn(Optional.of(buildUser(1L, request.getEmail(), "other", Role.PATIENT, true)));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));

        assertEquals("Cet email est déjà utilisé", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void register_pseudoAlreadyExists_throwsAndDoesNotSave() {

        RegisterRequest request = buildRegisterRequest(Role.PATIENT);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        when(userRepository.findByPseudo(request.getPseudo()))
                .thenReturn(Optional.of(buildUser(1L, "other@psyconnect.sn", request.getPseudo(), Role.PATIENT, true)));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));

        assertEquals("Ce pseudo est déjà utilisé", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void register_missingRole_throwsAndDoesNotSave() {

        RegisterRequest request = buildRegisterRequest(null);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        when(userRepository.findByPseudo(request.getPseudo())).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));

        assertEquals("Le rôle est requis", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

    @Test
    void register_roleAdmin_isBlocked() {

        RegisterRequest request = buildRegisterRequest(Role.ADMIN);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.empty());
        when(userRepository.findByPseudo(request.getPseudo())).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));

        assertEquals("Impossible de s'inscrire en tant qu'administrateur", ex.getMessage());
        verify(userRepository, never()).save(any(User.class));
    }

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

        assertEquals("Aucun compte ne correspond à cet email", ex.getMessage());
    }

    @Test
    void login_disabledAccount_throws() {

        LoginRequest request = new LoginRequest();
        request.setEmail("patient@psyconnect.sn");
        request.setPassword("password123");

        User user = buildUser(1L, request.getEmail(), "patient1", Role.PATIENT, false);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.of(user));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.login(request));

        assertEquals(
                "Votre compte a été suspendu par l'administrateur. "
                        + "Contactez-nous pour plus d'informations.",
                ex.getMessage()
        );
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

        assertEquals("Mot de passe incorrect", ex.getMessage());
    }

    @Test
    void login_unapprovedPsychologist_stillReturnsToken() {

        LoginRequest request = new LoginRequest();
        request.setEmail("psy@psyconnect.sn");
        request.setPassword("password123");
        User user = buildUser(7L, request.getEmail(), "psy1", Role.PSYCHOLOGIST, true);

        when(userRepository.findByEmail(request.getEmail())).thenReturn(Optional.of(user));
        when(passwordEncoder.matches(request.getPassword(), user.getPassword())).thenReturn(true);
        when(jwtService.generateToken(anyString(), anyString(), anyLong())).thenReturn("temporary-token");

        AuthResponse response = authService.login(request);

        assertEquals("temporary-token", response.getToken());
        assertEquals("PSYCHOLOGIST", response.getRole());
    }

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

        assertEquals("Aucun compte ne correspond à cet email", ex.getMessage());
    }
}
