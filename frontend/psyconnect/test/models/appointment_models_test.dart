import 'package:flutter_test/flutter_test.dart';
import 'package:psyconnect/features/patient/models/appointment_models.dart';

void main() {
  group('isoLocalDateTime', () {
    test('produit une date sans zone, comme LocalDateTime en Java', () {
      expect(
        isoLocalDateTime(DateTime(2026, 3, 5, 9, 7)),
        '2026-03-05T09:07:00',
      );
    });

    test('complète les secondes et les mois à deux chiffres', () {
      expect(
        isoLocalDateTime(DateTime(2026, 12, 31, 23, 59, 5)),
        '2026-12-31T23:59:05',
      );
    });
  });

  group('AppointmentStatusX', () {
    test('fait l\'aller-retour avec le backend pour chaque statut', () {
      for (final status in AppointmentStatus.values) {
        expect(AppointmentStatusX.fromApiValue(status.apiValue), status);
      }
    });

    test('ignore la casse', () {
      expect(
        AppointmentStatusX.fromApiValue('confirmed'),
        AppointmentStatus.confirmed,
      );
    });

    test('rejette un statut inconnu', () {
      expect(
        () => AppointmentStatusX.fromApiValue('POSTPONED'),
        throwsArgumentError,
      );
    });
  });

  group('ConsultationTypeX', () {
    test('fait l\'aller-retour avec le backend pour chaque type', () {
      for (final type in ConsultationType.values) {
        expect(ConsultationTypeX.fromApiValue(type.apiValue), type);
      }
    });

    test('affiche « Cabinet » pour une séance en présentiel', () {
      expect(ConsultationType.physical.label, 'Cabinet');
    });

    test('rejette un type inconnu', () {
      expect(
        () => ConsultationTypeX.fromApiValue('SMS'),
        throwsArgumentError,
      );
    });
  });

  group('CreateAppointmentRequest.toJson', () {
    test('envoie les dates en heure locale et le type attendu', () {
      final json = CreateAppointmentRequest(
        patientId: 4,
        psychologistId: 7,
        startTime: DateTime(2026, 10, 1, 10),
        endTime: DateTime(2026, 10, 1, 11),
        consultationType: ConsultationType.video,
      ).toJson();

      expect(json, {
        'patientId': 4,
        'psychologistId': 7,
        'startTime': '2026-10-01T10:00:00',
        'endTime': '2026-10-01T11:00:00',
        'consultationType': 'VIDEO',
      });
    });
  });

  group('RescheduleAppointmentRequest.toJson', () {
    test('envoie le nouveau créneau', () {
      final json = RescheduleAppointmentRequest(
        newStartTime: DateTime(2026, 10, 2, 14),
        newEndTime: DateTime(2026, 10, 2, 15),
      ).toJson();

      expect(json, {
        'newStartTime': '2026-10-02T14:00:00',
        'newEndTime': '2026-10-02T15:00:00',
      });
    });
  });

  group('Appointment.fromJson', () {
    Map<String, dynamic> appointmentJson() => {
          'id': 21,
          'patientId': 4,
          'psychologistId': 7,
          'startTime': '2026-10-01T10:00:00',
          'endTime': '2026-10-01T11:00:00',
          'consultationType': 'AUDIO',
          'status': 'PENDING',
          'createdAt': '2026-09-27T08:15:00',
        };

    test('lit un rendez-vous complet', () {
      final appointment = Appointment.fromJson(appointmentJson());

      expect(appointment.id, 21);
      expect(appointment.patientId, 4);
      expect(appointment.psychologistId, 7);
      expect(appointment.startTime, DateTime(2026, 10, 1, 10));
      expect(appointment.endTime, DateTime(2026, 10, 1, 11));
      expect(appointment.consultationType, ConsultationType.audio);
      expect(appointment.status, AppointmentStatus.pending);
      expect(appointment.createdAt, DateTime(2026, 9, 27, 8, 15));
    });

    test('prend la date de séance quand createdAt manque', () {
      final json = appointmentJson()..remove('createdAt');

      final appointment = Appointment.fromJson(json);

      expect(appointment.createdAt, appointment.startTime);
    });
  });
}
