package com.example.userservice.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

// disponibilite hebdomadaire d'un psychologue :
//   - dayOfWeek : 1 = Lundi ... 7 = Dimanche (même convention que DayOfWeek
//     Java et DateTime.weekday Flutter, pour eviter toute conversion)
//   - startHour / endHour : heures entieres (ex: 9 et 17)
//   - slotDurationMinutes : duree de chaque creneau (30/45/60/90/120 min)
//
// un psy peut avoir plusieurs lignes par jour (ex: 9-12 et 14-18)
// mais le cas le plus courant est une seule plage par jour de travail
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
