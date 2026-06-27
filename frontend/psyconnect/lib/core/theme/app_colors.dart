import 'package:flutter/material.dart';

/// Palette extraite de docs/PsyConnect Maquettes v2.html (variables CSS :root).
/// Garder ce fichier synchronisé avec la maquette si la charte évolue.
class AppColors {
  AppColors._();

  static const Color teal = Color(0xFF0D7B6E);
  static const Color tealDark = Color(0xFF095C52);
  static const Color tealLight = Color(0xFFE6F4F1);
  static const Color tealMid = Color(0xFFC2E8E2);

  static const Color gold = Color(0xFFD4A853);
  static const Color goldLight = Color(0xFFFBF3E2);

  static const Color rose = Color(0xFFE8746A);

  static const Color background = Color(0xFFF7F5F2);
  static const Color scaffoldOuter = Color(0xFFEDEBE6);
  static const Color white = Color(0xFFFFFFFF);

  static const Color text = Color(0xFF1A1A2E);
  static const Color muted = Color(0xFF7A7A8C);

  static const Color errorBg = Color(0xFFFDECEA);

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealDark, teal, Color(0xFF1DB39A)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealDark, teal],
  );
}
