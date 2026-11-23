import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';

Future<void> openDocument(
    Future<DownloadedFile> Function() load, String name) async {
  final file = await load();
  final extension = file.contentType.contains('pdf')
      ? 'pdf'
      : file.contentType.contains('png')
          ? 'png'
          : 'jpg';
  final dir = await getTemporaryDirectory();
  final local = File('${dir.path}/$name.$extension');
  await local.writeAsBytes(file.bytes, flush: true);
  await OpenFilex.open(local.path);
}
