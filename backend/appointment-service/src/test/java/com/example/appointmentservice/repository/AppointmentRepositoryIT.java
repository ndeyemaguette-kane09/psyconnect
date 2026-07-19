package com.example.appointmentservice.repository;

import static org.junit.jupiter.api.Assertions.*;

import java.time.LocalDateTime;
import java.util.EnumSet;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;

import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.entity.ConsultationType;

/**
 * Test d'intégration JPA : vérifie que les requêtes de détection de conflit
 * de créneau fonctionnent correctement contre une vraie base (H2 en mémoire).
 *
 * On utilise @DataJpaTest qui démarre uniquement la couche JPA, sans le
 * serveur web ni les clients REST — c'est rapide (~2 secondes).
 *
 * Le cas clé : un RDV annulé (CANCELLED) ne doit PAS bloquer le créneau.
 */
@DataJpaTest
class AppointmentRepositoryIT {

    @Autowired
    AppointmentRepository appointmentRepository;

    private static final Long PSY_ID     = 10L;
    private static final Long PATIENT_ID = 20L;

    // Créneau de référence : demain 10h → 11h
    private LocalDateTime slotStart;
    private LocalDateTime slotEnd;

    @BeforeEach
    void setUp() {
        appointmentRepository.deleteAll();
        slotStart = LocalDateTime.now().plusDays(1).withHour(10).withMinute(0).withSecond(0).withNano(0);
        slotEnd   = slotStart.plusHours(1);
    }

    // --- Helpers ---

    private Appointment save(AppointmentStatus status) {
        Appointment a = new Appointment();
        a.setPatientId(PATIENT_ID);
        a.setPsychologistId(PSY_ID);
        a.setStartTime(slotStart);
        a.setEndTime(slotEnd);
        a.setConsultationType(ConsultationType.VIDEO);
        a.setStatus(status);
        return appointmentRepository.save(a);
    }

    private boolean psyConflict() {
        return appointmentRepository
                .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        PSY_ID, slotEnd, slotStart,
                        EnumSet.of(AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED)
                );
    }

    private boolean patientConflict() {
        return appointmentRepository
                .existsByPatientIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        PATIENT_ID, slotEnd, slotStart,
                        EnumSet.of(AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED)
                );
    }

    // ── Conflits psy ───────────────────────────────────────────────────────────

    @Test
    @DisplayName("RDV PENDING du psy → conflit détecté")
    void psyConflict_whenPendingAppointmentExists() {
        save(AppointmentStatus.PENDING);
        assertTrue(psyConflict());
    }

    @Test
    @DisplayName("RDV CONFIRMED du psy → conflit détecté")
    void psyConflict_whenConfirmedAppointmentExists() {
        save(AppointmentStatus.CONFIRMED);
        assertTrue(psyConflict());
    }

    @Test
    @DisplayName("RDV CANCELLED du psy → pas de conflit (créneau libéré)")
    void psyConflict_whenCancelledAppointmentExists_noConflict() {
        save(AppointmentStatus.CANCELLED);
        assertFalse(psyConflict(),
                "Un RDV annulé ne doit pas bloquer le créneau");
    }

    @Test
    @DisplayName("RDV REJECTED du psy → pas de conflit")
    void psyConflict_whenRejectedAppointmentExists_noConflict() {
        save(AppointmentStatus.REJECTED);
        assertFalse(psyConflict());
    }

    @Test
    @DisplayName("Aucun RDV existant → pas de conflit")
    void psyConflict_whenNoAppointment_noConflict() {
        assertFalse(psyConflict());
    }

    // ── Conflits patient ───────────────────────────────────────────────────────

    @Test
    @DisplayName("RDV PENDING du patient → conflit détecté")
    void patientConflict_whenPendingAppointmentExists() {
        save(AppointmentStatus.PENDING);
        assertTrue(patientConflict());
    }

    @Test
    @DisplayName("RDV CANCELLED du patient → pas de conflit")
    void patientConflict_whenCancelledAppointmentExists_noConflict() {
        save(AppointmentStatus.CANCELLED);
        assertFalse(patientConflict(),
                "Un RDV annulé ne doit pas bloquer le créneau côté patient");
    }

    // ── Chevauchement partiel ──────────────────────────────────────────────────

    @Test
    @DisplayName("Nouveau créneau qui chevauche partiellement → conflit détecté")
    void psyConflict_whenPartialOverlap_detected() {
        save(AppointmentStatus.CONFIRMED); // 10h-11h

        // Nouveau créneau 10h30-11h30 : chevauche la moitié
        boolean overlap = appointmentRepository
                .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        PSY_ID,
                        slotStart.plusMinutes(30).plusHours(1), // newEnd = 11h30
                        slotStart.plusMinutes(30),              // newStart = 10h30
                        EnumSet.of(AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED)
                );

        assertTrue(overlap, "Un chevauchement partiel doit être détecté");
    }

    @Test
    @DisplayName("Créneau juste après (contigu) → pas de conflit")
    void psyConflict_whenAdjacentSlot_noConflict() {
        save(AppointmentStatus.CONFIRMED); // 10h-11h

        // Nouveau créneau 11h-12h : contigu mais ne chevauche pas
        boolean adjacent = appointmentRepository
                .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                        PSY_ID,
                        slotEnd.plusHours(1), // newEnd = 12h
                        slotEnd,              // newStart = 11h
                        EnumSet.of(AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED)
                );

        assertFalse(adjacent, "Un créneau contigu (non chevauchant) ne doit pas être un conflit");
    }

    // ── Test reschedule (IdNot) ────────────────────────────────────────────────

    @Test
    @DisplayName("Reschedule d'un RDV sur le même créneau → pas de conflit avec soi-même")
    void reschedule_sameSlot_doesNotConflictWithItself() {
        Appointment existing = save(AppointmentStatus.CONFIRMED);

        boolean selfConflict = appointmentRepository
                .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusInAndIdNot(
                        PSY_ID, slotEnd, slotStart,
                        EnumSet.of(AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED),
                        existing.getId() // on exclut le RDV qu'on modifie
                );

        assertFalse(selfConflict,
                "Le reschedule sur le même créneau ne doit pas conflicte avec lui-même");
    }
}
