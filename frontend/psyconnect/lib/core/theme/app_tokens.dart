import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppRadius {
  AppRadius._();

  static const double sm = 0;

  static const double md = 0;

  static const double lg = 0;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;

  static const double gutter = 20;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get sm => const <BoxShadow>[];

  static List<BoxShadow> get md => const <BoxShadow>[];

  static List<BoxShadow> get lg => const <BoxShadow>[];

  static List<BoxShadow> glow(Color color, {double opacity = 0.28}) =>
      const <BoxShadow>[];
}

class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 480);
  static const Duration entrance = Duration(milliseconds: 700);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeOut;
}

class AppDecorations {
  AppDecorations._();

  static BoxDecoration card({
    Color color = AppColors.white,
    double radius = AppRadius.md,
    List<BoxShadow>? shadow,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: shadow ?? AppShadows.sm,
      );

  static BoxDecoration tinted(Color background,
          {double radius = AppRadius.md}) =>
      BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      );

}
