package com.example.authservice.service.impl;

import com.example.authservice.dto.AdminStatsResponse;
import com.example.authservice.dto.UserAdminResponse;
import com.example.authservice.entity.Role;
import com.example.authservice.entity.User;
import com.example.authservice.repository.UserRepository;
import com.example.authservice.service.AdminService;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class AdminServiceImpl implements AdminService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public AdminServiceImpl(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    /**
     * Garde-fous communs aux actions destructrices/sensibles sur un compte
     * (désactivation, suppression, reset mot de passe) : un admin ne peut
     * agir ni sur un autre compte admin, ni sur son propre compte.
     */
    private void checkActionableTarget(User target, String callerEmail) {

        if (target.getRole() == Role.ADMIN) {
            throw new RuntimeException(
                    "Impossible d'effectuer cette action sur un compte administrateur"
            );
        }

        if (target.getEmail().equals(callerEmail)) {
            throw new RuntimeException(
                    "Vous ne pouvez pas effectuer cette action sur votre propre compte"
            );
        }
    }

    @Override
    public List<UserAdminResponse> listUsers() {

        return userRepository.findAll()
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public UserAdminResponse setUserEnabled(Long id, boolean enabled, String callerEmail) {

        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        if (user.getRole() == Role.ADMIN) {
            throw new RuntimeException(
                    "Impossible d'activer/désactiver un compte administrateur"
            );
        }

        if (user.getEmail().equals(callerEmail)) {
            throw new RuntimeException(
                    "Vous ne pouvez pas modifier votre propre compte"
            );
        }

        user.setEnabled(enabled);

        User saved = userRepository.save(user);

        return mapToResponse(saved);
    }

    @Override
    public void deleteUser(Long id, String callerEmail) {

        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        checkActionableTarget(user, callerEmail);

        userRepository.delete(user);
    }

    @Override
    public UserAdminResponse resetPassword(Long id, String newPassword, String callerEmail) {

        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé"));

        checkActionableTarget(user, callerEmail);

        user.setPassword(passwordEncoder.encode(newPassword));

        User saved = userRepository.save(user);

        return mapToResponse(saved);
    }

    @Override
    public AdminStatsResponse getStats() {

        AdminStatsResponse stats = new AdminStatsResponse();

        stats.setTotalUsers(userRepository.count());
        stats.setTotalPatients(userRepository.countByRole(Role.PATIENT));
        stats.setTotalPsychologists(userRepository.countByRole(Role.PSYCHOLOGIST));
        stats.setTotalAdmins(userRepository.countByRole(Role.ADMIN));
        stats.setEnabledUsers(userRepository.countByEnabled(true));
        stats.setDisabledUsers(userRepository.countByEnabled(false));

        return stats;
    }

    private UserAdminResponse mapToResponse(User user) {

        UserAdminResponse response = new UserAdminResponse();

        response.setId(user.getId());
        response.setEmail(user.getEmail());
        response.setPseudo(user.getPseudo());
        response.setFirstName(user.getFirstName());
        response.setLastName(user.getLastName());
        response.setRole(user.getRole().name());
        response.setEnabled(user.isEnabled());
        response.setCreatedAt(user.getCreatedAt());

        return response;
    }
}
