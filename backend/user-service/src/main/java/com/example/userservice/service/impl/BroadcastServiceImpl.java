package com.example.userservice.service.impl;

import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import com.example.userservice.client.NotificationClient;
import com.example.userservice.dto.BroadcastDto;
import com.example.userservice.dto.BroadcastRequest;
import com.example.userservice.entity.Broadcast;
import com.example.userservice.repository.BroadcastRepository;
import com.example.userservice.repository.PatientProfileRepository;
import com.example.userservice.repository.PsychologistProfileRepository;
import com.example.userservice.service.BroadcastService;

@Service
public class BroadcastServiceImpl implements BroadcastService {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(BroadcastServiceImpl.class);

    private final PatientProfileRepository patientRepo;
    private final PsychologistProfileRepository psychologistRepo;
    private final NotificationClient notificationClient;
    private final BroadcastRepository broadcastRepository;

    public BroadcastServiceImpl(
            PatientProfileRepository patientRepo,
            PsychologistProfileRepository psychologistRepo,
            NotificationClient notificationClient,
            BroadcastRepository broadcastRepository
    ) {
        this.patientRepo = patientRepo;
        this.psychologistRepo = psychologistRepo;
        this.notificationClient = notificationClient;
        this.broadcastRepository = broadcastRepository;
    }

    // ── validation commune ────────────────────────────────────────────────────

    private String resolveAudience(BroadcastRequest request) {
        if (request.getTitle() == null || request.getTitle().isBlank()) {
            throw new IllegalArgumentException("Le titre est obligatoire");
        }
        if (request.getMessage() == null || request.getMessage().isBlank()) {
            throw new IllegalArgumentException("Le message est obligatoire");
        }
        String audience = request.getAudience() == null
                ? "ALL"
                : request.getAudience().toUpperCase();
        if (!List.of("ALL", "PATIENTS", "PSYCHOLOGISTS").contains(audience)) {
            throw new IllegalArgumentException(
                    "Audience invalide : " + audience);
        }
        return audience;
    }

    private List<Long> collectTargetIds(String audience) {
        List<Long> ids = new ArrayList<>();
        if ("ALL".equals(audience) || "PATIENTS".equals(audience)) {
            patientRepo.findAll().forEach(p -> ids.add(p.getId()));
        }
        if ("ALL".equals(audience) || "PSYCHOLOGISTS".equals(audience)) {
            psychologistRepo.findAll().forEach(p -> ids.add(p.getId()));
        }
        return ids;
    }

    // retourne séparément les IDs patients et les IDs psychologues
    // (nécessaire pour passer le bon userRole à notification-service)
    private List<Long> collectPatientIds(String audience) {
        if ("ALL".equals(audience) || "PATIENTS".equals(audience)) {
            List<Long> ids = new ArrayList<>();
            patientRepo.findAll().forEach(p -> ids.add(p.getId()));
            return ids;
        }
        return List.of();
    }

    private List<Long> collectPsychologistIds(String audience) {
        if ("ALL".equals(audience) || "PSYCHOLOGISTS".equals(audience)) {
            List<Long> ids = new ArrayList<>();
            psychologistRepo.findAll().forEach(p -> ids.add(p.getId()));
            return ids;
        }
        return List.of();
    }

    // ── API publique ─────────────────────────────────────────────────────────

    @Override
    public int countTargets(BroadcastRequest request) {
        String audience = resolveAudience(request);
        return collectTargetIds(audience).size();
    }

    // persiste l'annonce en base AVANT l'envoi, puis envoie en @Async.
    // Ainsi le broadcast est lisible via GET /broadcasts même si
    // notification-service est temporairement indisponible.
    @Override
    @Async
    public void sendAsync(BroadcastRequest request) {
        String audience = resolveAudience(request);
        List<Long> ids = collectTargetIds(audience);

        // 1. persistance : l'annonce sera visible dès maintenant dans l'app
        Broadcast broadcast = new Broadcast();
        broadcast.setTitle(request.getTitle());
        broadcast.setMessage(request.getMessage());
        broadcast.setAudience(audience);
        broadcast.setRecipientCount(ids.size());
        broadcastRepository.save(broadcast);

        // 2. notifications individuelles (fire-and-forget, echec silencieux)
        // On sépare patients et psychologues pour passer le bon userRole,
        // évitant la fuite inter-comptes quand les profileId numériques coïncident.
        int sent = 0;
        List<Long> patientIds = collectPatientIds(audience);
        List<Long> psychologistIds = collectPsychologistIds(audience);
        for (Long id : patientIds) {
            try {
                notificationClient.send(
                        id,
                        request.getTitle(),
                        request.getMessage(),
                        "ANNOUNCEMENT",
                        "PATIENT"
                );
                sent++;
            } catch (Exception e) {
                LOGGER.warn("[broadcast] échec notif patient userId={} : {}",
                        id, e.getMessage());
            }
        }
        for (Long id : psychologistIds) {
            try {
                notificationClient.send(
                        id,
                        request.getTitle(),
                        request.getMessage(),
                        "ANNOUNCEMENT",
                        "PSYCHOLOGIST"
                );
                sent++;
            } catch (Exception e) {
                LOGGER.warn("[broadcast] échec notif psychologue userId={} : {}",
                        id, e.getMessage());
            }
        }
        int total = patientIds.size() + psychologistIds.size();
        LOGGER.info("[broadcast] «{}» → {}/{} notifs envoyées, persisté en base (audience={})",
                request.getTitle(), sent, total, audience);
    }

    // retourne les annonces filtrées selon le rôle Spring Security de l'appelant :
    // PATIENT  → ALL + PATIENTS
    // PSYCHOLOGIST → ALL + PSYCHOLOGISTS
    // ADMIN    → toutes (findAllByOrderBySentAtDesc)
    @Override
    public List<BroadcastDto> getBroadcastsForCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        boolean isAdmin = auth != null && auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
        boolean isPsy = auth != null && auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_PSYCHOLOGIST"));

        List<Broadcast> broadcasts;
        if (isAdmin) {
            broadcasts = broadcastRepository.findAllByOrderBySentAtDesc();
        } else if (isPsy) {
            broadcasts = broadcastRepository.findByAudienceInOrderBySentAtDesc(
                    List.of("ALL", "PSYCHOLOGISTS"));
        } else {
            // PATIENT (et cas par défaut)
            broadcasts = broadcastRepository.findByAudienceInOrderBySentAtDesc(
                    List.of("ALL", "PATIENTS"));
        }

        return broadcasts.stream().map(BroadcastDto::from).toList();
    }
}
