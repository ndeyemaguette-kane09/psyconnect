import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/psychologist_models.dart';

// modele de disponibilite hebdomadaire (reutilise depuis le cote patient)
class PsyAvailabilitySlot {
  const PsyAvailabilitySlot({
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
    required this.slotDurationMinutes,
  });

  final int dayOfWeek;
  final int startHour;
  final int endHour;
  final int slotDurationMinutes;

  // creneaux disponibles pour cette plage, sous forme TimeOfDay
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

  factory PsyAvailabilitySlot.fromJson(Map<String, dynamic> json) =>
      PsyAvailabilitySlot(
        dayOfWeek: json['dayOfWeek'] as int,
        startHour: json['startHour'] as int,
        endHour: json['endHour'] as int,
        slotDurationMinutes: json['slotDurationMinutes'] as int,
      );
}

// appelle user-service pour liste/detail des psys, et ml-service pour la reco
// ?verifiedOnly=true car un patient doit pas voir un psy refuse ou pas verifie
// le reste des filtres (ville, langue...) c'est cote client
class PsychologistService {
  PsychologistService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<PsychologistProfile>> getAllPsychologists() async {
    final json = await _api
        .get('${ApiConstants.psychologistProfiles}?verifiedOnly=true');
    return (json as List)
        .map((e) => PsychologistProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PsychologistProfile> getPsychologistById(int id) async {
    final json =
        await _api.get('${ApiConstants.psychologistProfiles}/$id');
    return PsychologistProfile.fromJson(json as Map<String, dynamic>);
  }

  // recos du ml-service. peut lever une erreur si service down,
  // c'est a l'appelant de gerer le repli
  Future<List<PsychologistProfile>> getRecommendations(
    int patientId, {
    int topN = 5,
  }) async {
    final json = await _api
        .get(ApiConstants.recommendations(patientId, topN: topN));
    final recommendations =
        (json as Map<String, dynamic>)['recommendations'] as List;
    return recommendations
        .map((e) => PsychologistProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // liste publique et anonyme des avis sur ce psy
  Future<List<PsychologistReview>> getReviews(int psychologistId) async {
    final json =
        await _api.get(ApiConstants.psychologistReviews(psychologistId));
    return (json as List)
        .map((e) => PsychologistReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // l'avis du patient connecte sur ce psy (rating=null si pas encore d'avis)
  Future<PsychologistReview> getMyReview(int psychologistId) async {
    final json =
        await _api.get(ApiConstants.psychologistMyReview(psychologistId));
    return PsychologistReview.fromJson(json as Map<String, dynamic>);
  }

  // disponibilites hebdomadaires du psy : utilisees par le patient pour
  // ne voir que les vrais creneaux au lieu de la liste hardcodee
  Future<List<PsyAvailabilitySlot>> getAvailabilities(
      int psychologistId) async {
    final json = await _api
        .get(ApiConstants.psychologistAvailabilities(psychologistId));
    return (json as List)
        .map((e) =>
            PsyAvailabilitySlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // liste des psys disponibles pour urgence maintenant
  Future<List<PsychologistProfile>> getEmergencyPsychologists() async {
    final json = await _api.get(ApiConstants.emergencyPsychologists);
    return (json as List)
        .map((e) => PsychologistProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // le psy active/désactive son mode urgence depuis son profil
  Future<PsychologistProfile> toggleEmergencyAvailability(
    int psychologistId, {
    required bool available,
    bool freeSession = false,
  }) async {
    final json = await _api.put(
      '${ApiConstants.psychologistEmergencyStatus(psychologistId)}'
      '?available=$available&freeSession=$freeSession',
    );
    return PsychologistProfile.fromJson(json as Map<String, dynamic>);
  }

  // cree ou met a jour l'avis (upsert), reserve au patient ayant eu une
  // seance COMPLETED avec ce psy (verifie cote backend)
  Future<PsychologistReview> submitReview(
    int psychologistId, {
    required int rating,
    String? comment,
  }) async {
    final json = await _api.put(
      ApiConstants.psychologistReview(psychologistId),
      body: {
        'rating': rating,
        if (comment != null) 'comment': comment,
      },
    );
    return PsychologistReview.fromJson(json as Map<String, dynamic>);
  }
}
