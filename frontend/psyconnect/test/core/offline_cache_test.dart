import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:psyconnect/core/network/api_client.dart';
import 'package:psyconnect/core/network/api_exception.dart';
import 'package:psyconnect/core/storage/offline_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var online = true;
  var status = 200;

  final client = ApiClient(
    client: MockClient((request) async {
      if (!online) throw http.ClientException('pas de réseau');
      return http.Response(
        jsonEncode([
          {'id': 1, 'status': 'CONFIRMED'}
        ]),
        status,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await OfflineCache.clear();
    online = true;
    status = 200;
  });

  test('relit la dernière réponse quand le serveur est injoignable', () async {
    await client.get('/appointments/patient/1');
    await pumpEventQueue();

    online = false;
    final data = await client.get('/appointments/patient/1');

    expect(data, [
      {'id': 1, 'status': 'CONFIRMED'}
    ]);
    expect(OfflineCache.isOffline.value, isTrue);
  });

  test('le bandeau disparaît dès que le serveur répond à nouveau', () async {
    await client.get('/appointments/patient/1');
    await pumpEventQueue();
    online = false;
    await client.get('/appointments/patient/1');

    online = true;
    await client.get('/appointments/patient/1');

    expect(OfflineCache.isOffline.value, isFalse);
  });

  test("sans copie enregistrée, l'erreur réseau remonte", () async {
    online = false;

    await expectLater(
      client.get('/appointments/patient/1'),
      throwsA(isA<ApiException>()),
    );
  });

  test('une erreur du serveur ne renvoie pas la copie', () async {
    await client.get('/appointments/patient/1');
    await pumpEventQueue();

    status = 403;

    await expectLater(
      client.get('/appointments/patient/1'),
      throwsA(isA<ApiException>()),
    );
  });

  test('la déconnexion efface les copies', () async {
    await client.get('/appointments/patient/1');
    await pumpEventQueue();

    await OfflineCache.clear();

    expect(await OfflineCache.read('/appointments/patient/1'), isNull);
  });
}
