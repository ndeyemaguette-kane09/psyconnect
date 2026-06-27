package com.example.authservice.config;

import com.example.authservice.entity.Role;
import com.example.authservice.entity.User;
import com.example.authservice.repository.UserRepository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Crée un compte ADMIN par défaut au démarrage de l'application, s'il n'en
 * existe pas déjà. Nécessaire car {@code AuthService.register()} interdit
 * volontairement l'inscription publique en tant qu'ADMIN (voir
 * "Cannot register as admin") : c'est donc le seul mécanisme de création
 * d'un premier compte administrateur.
 *
 * Idempotent : si un utilisateur avec le rôle ADMIN existe déjà, ne fait
 * rien (ne réinitialise pas son mot de passe).
 */
@Component
public class AdminBootstrap implements CommandLineRunner {

    private static final Logger LOGGER = LoggerFactory.getLogger(AdminBootstrap.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    private final String adminEmail;
    private final String adminPassword;
    private final String adminPseudo;
    private final String adminFirstName;
    private final String adminLastName;

    public AdminBootstrap(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            @Value("${admin.email}") String adminEmail,
            @Value("${admin.password}") String adminPassword,
            @Value("${admin.pseudo}") String adminPseudo,
            @Value("${admin.first-name}") String adminFirstName,
            @Value("${admin.last-name}") String adminLastName
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.adminEmail = adminEmail;
        this.adminPassword = adminPassword;
        this.adminPseudo = adminPseudo;
        this.adminFirstName = adminFirstName;
        this.adminLastName = adminLastName;
    }

    @Override
    public void run(String... args) {

        if (userRepository.countByRole(Role.ADMIN) > 0) {
            LOGGER.info("Compte(s) ADMIN déjà présent(s) — bootstrap ignoré.");
            return;
        }

        if (userRepository.findByEmail(adminEmail).isPresent()
                || userRepository.findByPseudo(adminPseudo).isPresent()) {
            LOGGER.warn(
                    "Aucun ADMIN trouvé mais l'email/pseudo admin par défaut ({}, {}) est déjà pris — bootstrap ignoré.",
                    adminEmail,
                    adminPseudo
            );
            return;
        }

        User admin = new User();
        admin.setEmail(adminEmail);
        admin.setPassword(passwordEncoder.encode(adminPassword));
        admin.setPseudo(adminPseudo);
        admin.setRole(Role.ADMIN);
        admin.setFirstName(adminFirstName);
        admin.setLastName(adminLastName);

        userRepository.save(admin);

        LOGGER.info("Compte ADMIN par défaut créé : {}", adminEmail);
    }
}
