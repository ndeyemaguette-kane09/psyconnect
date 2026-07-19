package com.example.userservice.service.impl;

import com.example.userservice.dto.AvailabilityRequest;
import com.example.userservice.dto.AvailabilityResponse;
import com.example.userservice.entity.PsychologistAvailability;
import com.example.userservice.entity.PsychologistProfile;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.PsychologistAvailabilityRepository;
import com.example.userservice.repository.PsychologistProfileRepository;
import com.example.userservice.service.AvailabilityService;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class AvailabilityServiceImpl implements AvailabilityService {

    private final PsychologistAvailabilityRepository availabilityRepository;
    private final PsychologistProfileRepository psychologistProfileRepository;

    public AvailabilityServiceImpl(
            PsychologistAvailabilityRepository availabilityRepository,
            PsychologistProfileRepository psychologistProfileRepository
    ) {
        this.availabilityRepository = availabilityRepository;
        this.psychologistProfileRepository = psychologistProfileRepository;
    }

    @Override
    public List<AvailabilityResponse> getAvailabilities(Long psychologistProfileId) {
        return availabilityRepository
                .findByPsychologistProfileIdOrderByDayOfWeekAscStartHourAsc(psychologistProfileId)
                .stream()
                .map(this::mapToResponse)
                .toList();
    }

    // Remplacement atomique : supprime tout puis réinsère (transaction)
    // garantit qu'on ne laisse jamais un etat partiel
    @Override
    @Transactional
    public List<AvailabilityResponse> replaceAvailabilities(
            Long psychologistProfileId,
            List<AvailabilityRequest> requests,
            Long callerAuthUserId
    ) {
        PsychologistProfile profile = psychologistProfileRepository
                .findById(psychologistProfileId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Profil psychologue introuvable"
                ));

        // seul le proprietaire du profil peut modifier ses disponibilites
        if (!profile.getAuthUserId().equals(callerAuthUserId)) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez modifier que vos propres disponibilités"
            );
        }

        // validation metier : endHour > startHour sur chaque entree
        for (AvailabilityRequest r : requests) {
            if (r.getEndHour() <= r.getStartHour()) {
                throw new IllegalArgumentException(
                        "L'heure de fin doit être postérieure à l'heure de début"
                );
            }
        }

        // delete all + insert en une seule transaction
        availabilityRepository.deleteByPsychologistProfileId(psychologistProfileId);

        List<PsychologistAvailability> saved = requests.stream().map(r -> {
            PsychologistAvailability a = new PsychologistAvailability();
            a.setPsychologistProfileId(psychologistProfileId);
            a.setDayOfWeek(r.getDayOfWeek());
            a.setStartHour(r.getStartHour());
            a.setEndHour(r.getEndHour());
            a.setSlotDurationMinutes(r.getSlotDurationMinutes());
            return availabilityRepository.save(a);
        }).toList();

        return saved.stream().map(this::mapToResponse).toList();
    }

    private AvailabilityResponse mapToResponse(PsychologistAvailability a) {
        AvailabilityResponse r = new AvailabilityResponse();
        r.setId(a.getId());
        r.setPsychologistProfileId(a.getPsychologistProfileId());
        r.setDayOfWeek(a.getDayOfWeek());
        r.setStartHour(a.getStartHour());
        r.setEndHour(a.getEndHour());
        r.setSlotDurationMinutes(a.getSlotDurationMinutes());
        return r;
    }
}
