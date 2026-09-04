package com.example.authservice.service;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.List;

import com.example.authservice.dto.AuthResponse;
import com.example.authservice.dto.ForgotPasswordRequest;
import com.example.authservice.dto.ForgotPasswordResponse;
import com.example.authservice.dto.LoginRequest;
import com.example.authservice.exception.BannedAccountException;
import com.example.authservice.dto.MessageResponse;
import com.example.authservice.dto.RegisterRequest;
import com.example.authservice.dto.ResetPasswordWithCodeRequest;
import com.example.authservice.entity.PasswordResetCode;
import com.example.authservice.entity.Role;
import com.example.authservice.entity.User;
import com.example.authservice.repository.PasswordResetCodeRepository;
import com.example.authservice.repository.UserRepository;
import com.example.authservice.security.JwtService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private static final Logger LOGGER = LoggerFactory.getLogger(AuthService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int CODE_VALIDITY_MINUTES = 15;
    private static final int MAX_CODE_ATTEMPTS = 5;

    private final UserRepository userRepository;
    private final PasswordResetCodeRepository passwordResetCodeRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    private final PasswordResetMailer passwordResetMailer;
    private final ResetRequestThrottle resetRequestThrottle;

    public AuthService(UserRepository userRepository,
                       PasswordResetCodeRepository passwordResetCodeRepository,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService,
                       PasswordResetMailer passwordResetMailer,
                       ResetRequestThrottle resetRequestThrottle) {

        this.userRepository = userRepository;
        this.passwordResetCodeRepository = passwordResetCodeRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.passwordResetMailer = passwordResetMailer;
        this.resetRequestThrottle = resetRequestThrottle;
    }

    public MessageResponse register(RegisterRequest request) {

        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new RuntimeException("Cet email est déjà utilisé");
        }

        if (userRepository.findByPseudo(request.getPseudo()).isPresent()) {
            throw new RuntimeException("Ce pseudo est déjà utilisé");
        }

        if (request.getRole() == null) {
            throw new RuntimeException("Le rôle est requis");
        }

        if (request.getRole() == Role.ADMIN) {
            throw new RuntimeException("Impossible de s'inscrire en tant qu'administrateur");
        }

        User user = new User();

        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setPseudo(request.getPseudo());
        user.setRole(request.getRole());
        user.setFirstName(request.getFirstName());
        user.setLastName(request.getLastName());

        userRepository.save(user);

        return new MessageResponse("Inscription réussie");
    }

    public MessageResponse updatePseudo(String email, String newPseudo) {

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Utilisateur introuvable"));

        if (!newPseudo.equals(user.getPseudo())
                && userRepository.findByPseudo(newPseudo).isPresent()) {
            throw new RuntimeException("Ce pseudo est déjà utilisé");
        }

        user.setPseudo(newPseudo);
        userRepository.save(user);

        return new MessageResponse("Pseudo mis à jour");
    }

    public AuthResponse login(LoginRequest request) {

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("Aucun compte ne correspond à cet email"));

        if (!user.isEnabled()) {
            throw new BannedAccountException();
        }

        boolean passwordMatches = passwordEncoder.matches(
                request.getPassword(),
                user.getPassword()
        );

        if (!passwordMatches) {
            throw new RuntimeException("Mot de passe incorrect");
        }

        String token = jwtService.generateToken(
                user.getEmail(),
                user.getRole().name(),
                user.getId()
        );

        return new AuthResponse(
                token,
                user.getRole().name(),
                user.getId(),
                user.getPseudo()
        );
    }

    public AuthResponse getCurrentUser(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Aucun compte ne correspond à cet email"));

        return new AuthResponse(
                null,
                user.getRole().name(),
                user.getId(),
                user.getPseudo()
        );
    }

    public ForgotPasswordResponse forgotPassword(ForgotPasswordRequest request) {

        ForgotPasswordResponse generic = new ForgotPasswordResponse(
                "Si un compte existe avec cet email, "
                        + "un code de réinitialisation vient d'être envoyé."
        );

        if (!resetRequestThrottle.allow(request.getEmail())) {
            LOGGER.warn("Trop de demandes de réinitialisation pour un même email");
            return generic;
        }

        User user = userRepository.findByEmail(request.getEmail()).orElse(null);

        if (user == null) {
            return generic;
        }

        List<PasswordResetCode> previous =
                passwordResetCodeRepository.findByUserIdAndUsedFalse(user.getId());
        previous.forEach(old -> old.setUsed(true));
        passwordResetCodeRepository.saveAll(previous);

        String code = String.format("%06d", RANDOM.nextInt(1_000_000));

        PasswordResetCode resetCode = new PasswordResetCode();
        resetCode.setUserId(user.getId());
        resetCode.setCodeHash(passwordEncoder.encode(code));
        resetCode.setExpiresAt(LocalDateTime.now().plusMinutes(CODE_VALIDITY_MINUTES));
        resetCode.setUsed(false);
        resetCode.setAttempts(0);
        passwordResetCodeRepository.save(resetCode);

        passwordResetMailer.sendResetCode(
                user.getEmail(), code, CODE_VALIDITY_MINUTES);

        LOGGER.info(
                "Code de réinitialisation généré pour userId={} (valable {} min)",
                user.getId(), CODE_VALIDITY_MINUTES
        );

        return generic;
    }

    public MessageResponse resetPasswordWithCode(ResetPasswordWithCodeRequest request) {

        RuntimeException invalid = new RuntimeException("Code invalide ou expiré");

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> invalid);

        PasswordResetCode resetCode = passwordResetCodeRepository
                .findFirstByUserIdAndUsedFalseOrderByCreatedAtDesc(user.getId())
                .orElseThrow(() -> invalid);

        if (resetCode.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw invalid;
        }

        if (resetCode.getAttempts() >= MAX_CODE_ATTEMPTS) {
            resetCode.setUsed(true);
            passwordResetCodeRepository.save(resetCode);
            throw invalid;
        }

        if (!passwordEncoder.matches(request.getCode(), resetCode.getCodeHash())) {
            resetCode.setAttempts(resetCode.getAttempts() + 1);
            if (resetCode.getAttempts() >= MAX_CODE_ATTEMPTS) {
                resetCode.setUsed(true);
            }
            passwordResetCodeRepository.save(resetCode);
            throw invalid;
        }

        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        resetCode.setUsed(true);
        passwordResetCodeRepository.save(resetCode);

        return new MessageResponse("Mot de passe réinitialisé avec succès");
    }
}
