package com.example.userservice.service.impl;

import com.example.userservice.client.AppointmentClient;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.entity.PsyPatientLink;
import com.example.userservice.repository.PatientProfileRepository;
import com.example.userservice.repository.PsychologistProfileRepository;
import com.example.userservice.repository.PsyPatientLinkRepository;
import com.example.userservice.service.PsyPatientLinkService;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PsyPatientLinkServiceImpl implements PsyPatientLinkService {

    private final PsyPatientLinkRepository linkRepository;
    private final PsychologistProfileRepository psychologistRepository;
    private final PatientProfileRepository patientRepository;
    private final AppointmentClient appointmentClient;

    public PsyPatientLinkServiceImpl(
            PsyPatientLinkRepository linkRepository,
            PsychologistProfileRepository psychologistRepository,
            PatientProfileRepository patientRepository,
            AppointmentClient appointmentClient
    ) {
        this.linkRepository = linkRepository;
        this.psychologistRepository = psychologistRepository;
        this.patientRepository = patientRepository;
        this.appointmentClient = appointmentClient;
    }

    @Override
    public void addFollowedPatient(Long psyProfileId, Long patientProfileId, Long callerAuthUserId) {
        ensureCallerOwnsPsychologistProfile(psyProfileId, callerAuthUserId);
        ensurePatientExists(patientProfileId);

        // upsert : si le lien existe déjà, pas de doublon grâce à la contrainte unique
        if (!linkRepository.existsByPsychologistProfileIdAndPatientProfileId(
                psyProfileId, patientProfileId)) {
            if (!appointmentClient.hasAcceptedAppointmentBetween(psyProfileId, patientProfileId)) {
                throw new ForbiddenOperationException(
                        "Vous ne pouvez suivre un patient qu'après avoir accepté un rendez-vous avec lui"
                );
            }
            PsyPatientLink link = new PsyPatientLink();
            link.setPsychologistProfileId(psyProfileId);
            link.setPatientProfileId(patientProfileId);
            linkRepository.save(link);
        }
    }

    @Override
    public void removeFollowedPatient(Long psyProfileId, Long patientProfileId, Long callerAuthUserId) {
        ensureCallerOwnsPsychologistProfile(psyProfileId, callerAuthUserId);
        // pas d'erreur si le lien n'existe pas : opération idempotente
        linkRepository.deleteByPsychologistProfileIdAndPatientProfileId(
                psyProfileId, patientProfileId);
    }

    @Override
    public List<Long> getFollowedPatientIds(Long psyProfileId, Long callerAuthUserId) {
        ensureCallerOwnsPsychologistProfile(psyProfileId, callerAuthUserId);
        return linkRepository.findPatientIdsByPsychologistProfileId(psyProfileId);
    }

    @Override
    public boolean isFollowing(Long psyProfileId, Long patientProfileId) {
        return linkRepository.existsByPsychologistProfileIdAndPatientProfileId(
                psyProfileId, patientProfileId);
    }

    // garantit que l'appelant est bien le psy propriétaire du profil (pas un autre psy ni un admin)
    private void ensureCallerOwnsPsychologistProfile(Long psyProfileId, Long callerAuthUserId) {
        var profile = psychologistRepository
                .findByAuthUserId(callerAuthUserId)
                .orElseThrow(() -> new ForbiddenOperationException(
                        "Seul un psychologue authentifié peut gérer ses patients suivis"
                ));
        if (!profile.getId().equals(psyProfileId)) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez gérer que vos propres patients suivis"
            );
        }
    }

    private void ensurePatientExists(Long patientProfileId) {
        if (!patientRepository.existsById(patientProfileId)) {
            throw new ResourceNotFoundException("Patient introuvable");
        }
    }
}
