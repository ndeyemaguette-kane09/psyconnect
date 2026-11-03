package com.example.userservice.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

// disponibilité hebdo d'un psy, dayOfWeek 1 = lundi ... 7 = dimanche
// (comme DateTime.weekday côté Flutter), plusieurs plages possibles par jour
@Entity
@Getter
@Setter
@Table(name = "psychologist_availabilities")
public class PsychologistAvailability {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long psychologistProfileId;

    // 1 = Lundi, 7 = Dimanche
    @Column(nullable = false)
    private Integer dayOfWeek;

    // heure de debut (inclusive) : 0..23
    @Column(nullable = false)
    private Integer startHour;

    // heure de fin (exclusive) : 1..24
    // ex: startHour=9 endHour=17 -> creneaux a 9h, 10h, ..., 16h si slot=60min
    @Column(nullable = false)
    private Integer endHour;

    // duree de chaque creneau en minutes : 30, 45, 60, 90 ou 120
    @Column(nullable = false)
    private Integer slotDurationMinutes = 60;

    public PsychologistAvailability() {
    }
}
