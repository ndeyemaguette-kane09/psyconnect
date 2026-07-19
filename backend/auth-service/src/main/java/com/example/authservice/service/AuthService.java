package com.example.authservice.service;

import java.security.SecureRandom;
import java.time.LocalDateTime;

import com.example.authservice.client.PsychologistApprovalClient;
import com.example.authservice.client.PsychologistApprovalClient.ApprovalStatus;
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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private static final Logger LOGGER = LoggerFactory.getLogger(AuthService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int CODE_VALIDITY_MINUTES = 15;

    private final UserRepository userRepository;
    private final PasswordResetCodeRepository passwordResetCodeRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final PsychologistApprovalClient psychologistApprovalClient;

    // Tant qu'aucun envoi d'email réel n'est branché, le code de réinitialisation est
    // renvoyé dans la réponse HTTP (en plus d'être loggué) pour rester
    // testable. À désactiver (false) dès qu'un vrai envoi d'email existe :
    // sinon n'importe qui connaissant un email peut réinitialiser ce compte
    @Value("${app.password-reset.expose-code-in-response:true}")
    private boolean exposeCodeInResponse;

    public AuthService(UserRepository userRepository,
                       PasswordResetCodeRepository passwordResetCodeRepository,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService,
                       PsychologistApprovalClient psychologistApprovalClient) {

        this.userRepository = userRepository;
        this.passwordResetCodeRepository = passwordResetCodeRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.psychologistApprovalClient = psychologistApprovalClient;
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

        // Un psychologue non encore approuvé par un administrateur ne doit
        // pas pouvoir se connecter. On utilise le token qui vient d'être
        // généré (jamais renvoyé si on bloque ici) pour interroger
        // user-service sur le statut du profil. NO_PROFILE = inscription
        // en cours (étape 2 du flux d'inscription n'a pas encore créé le
        // profil) → on laisse passer, sinon le compte ne pourrait jamais
        // finir son inscription
        if (user.getRole() == Role.PSYCHOLOGIST) {
            ApprovalStatus status = psychologistApprovalClient.checkApprovalStatus(
                    user.getId(),
                    "Bearer " + token
            );

            if (status == ApprovalStatus.REJECTED) {
                throw new RuntimeException(
                        "Votre demande d'inscription en tant que psychologue a été refusée. "
                                + "Contactez le support PsyConnect pour plus d'informations."
                );
            }

            if (status == ApprovalStatus.PENDING) {
                throw new RuntimeException(
                        "Votre profil est en attente de validation par un administrateur. "
                                + "Vous pourrez vous connecter dès qu'il sera approuvé."
                );
            }
        }

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

    // Réponse volontairement identique que l'email existe ou non, pour ne
    // pas révéler quels emails ont un compte. Si le compte existe, on génère
    // un code et on invalide les codes précédents non utilisés (un seul code
    // valide à la fois par utilisateur)
    public ForgotPasswordResponse forgotPassword(ForgotPasswordRequest request) {

        String generic = "Si un compte existe avec cet email, "
                + "un code de réinitialisation vient d'être envoyé.";

        User user = userRepository.findByEmail(request.getEmail()).orElse(null);

        if (user == null) {
            return new ForgotPasswordResponse(generic, null);
        }

        passwordResetCodeRepository
                .findByUserIdAndUsedFalse(user.getId())
                .forEach(old -> old.setUsed(true));

        String code = String.format("%06d", RANDOM.nextInt(1_000_000));

        PasswordResetCode resetCode = new PasswordResetCode();
        resetCode.setUserId(user.getId());
        resetCode.setCode(code);
        resetCode.setExpiresAt(LocalDateTime.now().plusMinutes(CODE_VALIDITY_MINUTES));
        resetCode.setUsed(false);
        passwordResetCodeRepository.save(resetCode);

        // Tant qu'aucun envoi d'email réel n'existe, c'est la seule trace du
        // code. Utile pour le suivi une fois exposeCodeInResponse désactivé
        LOGGER.info(
                "Code de réinitialisation pour {} (userId={}) : {} (valable {} min)",
                user.getEmail(), user.getId(), code, CODE_VALIDITY_MINUTES
        );

        return new ForgotPasswordResponse(generic, exposeCodeInResponse ? code : null);
    }

    public MessageResponse resetPasswordWithCode(ResetPasswordWithCodeRequest request) {

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("Code invalide ou expiré"));

        PasswordResetCode resetCode = passwordResetCodeRepository
                .findByUserIdAndCodeAndUsedFalse(user.getId(), request.getCode())
                .orElseThrow(() -> new RuntimeException("Code invalide ou expiré"));

        if (resetCode.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("Code invalide ou expiré");
        }

        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        resetCode.setUsed(true);
        passwordResetCodeRepository.save(resetCode);

        return new MessageResponse("Mot de passe réinitialisé avec succès");
    }
}
