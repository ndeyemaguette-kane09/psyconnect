import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../network/api_client.dart';

// l'onglet est ouvert avant le téléchargement, sinon Safari le bloque
Future<void> openDocument(
    Future<DownloadedFile> Function() load, String name) async {
  final tab = web.window.open('', '_blank');
  try {
    final file = await load();
    final blob = web.Blob(
      [file.bytes.toJS].toJS,
      web.BlobPropertyBag(type: file.contentType),
    );
    final url = web.URL.createObjectURL(blob);
    if (tab == null) {
      web.window.open(url, '_blank');
    } else {
      tab.location.href = url;
    }
  } catch (_) {
    tab?.close();
    rethrow;
  }
}
