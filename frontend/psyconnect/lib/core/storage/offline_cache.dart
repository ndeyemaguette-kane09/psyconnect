import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// dernières réponses GET reçues, relues quand le serveur est injoignable
class OfflineCache {
  OfflineCache._();

  static const _storage = FlutterSecureStorage();
  static const _prefix = 'cache:';

  static final ValueNotifier<bool> isOffline = ValueNotifier(false);

  static Future<void> save(String path, dynamic data) async {
    if (kIsWeb || data == null) return;
    try {
      await _storage.write(key: '$_prefix$path', value: jsonEncode(data));
    } catch (_) {}
  }

  static Future<dynamic> read(String path) async {
    if (kIsWeb) return null;
    try {
      final raw = await _storage.read(key: '$_prefix$path');
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    isOffline.value = false;
    if (kIsWeb) return;
    try {
      final all = await _storage.readAll();
      await Future.wait(all.keys
          .where((key) => key.startsWith(_prefix))
          .map((key) => _storage.delete(key: key)));
    } catch (_) {}
  }
}
