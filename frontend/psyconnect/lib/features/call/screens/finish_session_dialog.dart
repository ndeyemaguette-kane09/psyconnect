import 'package:flutter/material.dart';

Future<bool> confirmFinishSession(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Terminer la séance ?'),
      content: const Text(
          'La séance sera clôturée. Le patient pourra laisser un avis et vous '
          'pourrez écrire vos recommandations.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Terminer'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
