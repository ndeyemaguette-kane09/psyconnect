import 'package:flutter/material.dart';

// plage de disponibilite hebdomadaire d'un psychologue
// dayOfWeek : 1=Lundi ... 7=Dimanche (meme convention que DateTime.weekday)
// startHour/endHour : heures entieres (ex: 9 et 17)
// slotDurationMinutes : 30, 45, 60, 90 ou 120
class PsychologistAvailability {
  const PsychologistAvailability({
    required this.id,
    required this.psychologistProfileId,
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
    required this.slotDurationMinutes,
  });

  final int id;
  final int psychologistProfileId;
  final int dayOfWeek; // 1=Lundi, 7=Dimanche
  final int startHour;
  final int endHour;
  final int slotDurationMinutes;

  // genere la liste des creneaux disponibles pour cette plage
  // retourne des TimeOfDay (heure + minutes), de startHour a endHour exclusif
  // ex: start=9 end=17 slot=60 -> 9h00, 10h00, 11h00, ..., 16h00
  // ex: start=9 end=12 slot=30 -> 9h00, 9h30, 10h00, 10h30, 11h00, 11h30
  List<TimeOfDay> get slots {
    final result = <TimeOfDay>[];
    int totalMinutes = startHour * 60;
    final endMinutes = endHour * 60;
    while (totalMinutes + slotDurationMinutes <= endMinutes) {
      result.add(TimeOfDay(
        hour: totalMinutes ~/ 60,
        minute: totalMinutes % 60,
      ));
      totalMinutes += slotDurationMinutes;
    }
    return result;
  }

  factory PsychologistAvailability.fromJson(Map<String, dynamic> json) {
    return PsychologistAvailability(
      id: json['id'] as int,
      psychologistProfileId: json['psychologistProfileId'] as int,
      dayOfWeek: json['dayOfWeek'] as int,
      startHour: json['startHour'] as int,
      endHour: json['endHour'] as int,
      slotDurationMinutes: json['slotDurationMinutes'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'startHour': startHour,
        'endHour': endHour,
        'slotDurationMinutes': slotDurationMinutes,
      };
}

// DTO pour l'envoi (sans id)
class AvailabilityRequest {
  const AvailabilityRequest({
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
    required this.slotDurationMinutes,
  });

  final int dayOfWeek;
  final int startHour;
  final int endHour;
  final int slotDurationMinutes;

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'startHour': startHour,
        'endHour': endHour,
        'slotDurationMinutes': slotDurationMinutes,
      };
}

// noms courts des jours (meme index que DateTime.weekday)
const kWeekdayLabels = [
  '',      // 0 : padding (weekday commence a 1)
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];
