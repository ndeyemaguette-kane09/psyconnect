import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

class AppTheme {
  AppTheme._();

  static const Color _shadow = Color(0x140B3B34);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.teal,
        onPrimary: AppColors.white,
        secondary: AppColors.gold,
        onSecondary: AppColors.white,
        error: AppColors.danger,
        onError: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.text,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = _textTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      shadowColor: _shadow,
      dividerColor: AppColors.border,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.text, size: 22),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.tealMid,
          disabledForegroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: GoogleFonts.figtree(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, 46),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: GoogleFonts.figtree(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.teal,
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.tealMid, width: 1.4),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: GoogleFonts.figtree(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          textStyle: GoogleFonts.figtree(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
        foregroundColor: AppColors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        labelStyle: GoogleFonts.figtree(color: AppColors.muted, fontSize: 14),
        floatingLabelStyle: GoogleFonts.figtree(
          color: AppColors.teal,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.figtree(color: AppColors.faint, fontSize: 14),
        errorStyle: GoogleFonts.figtree(color: AppColors.danger, fontSize: 12),
        helperStyle: GoogleFonts.figtree(color: AppColors.muted, fontSize: 12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.teal,
        selectionColor: AppColors.tealMid.withValues(alpha: 0.6),
        selectionHandleColor: AppColors.teal,
      ),

      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: GoogleFonts.figtree(
          color: AppColors.white,
          fontSize: 13.5,
        ),
        actionTextColor: AppColors.gold,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.teal,
        textColor: AppColors.text,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: AppRadius.smAll,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: GoogleFonts.figtree(color: AppColors.white, fontSize: 12),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.teal,
        disabledColor: AppColors.surfaceAlt,
        checkmarkColor: AppColors.white,
        showCheckmark: false,
        side: const BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        labelStyle: GoogleFonts.figtree(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        secondaryLabelStyle: GoogleFonts.figtree(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0,
        pressElevation: 0,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.rose,
        textColor: AppColors.white,
        textStyle: GoogleFonts.figtree(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.teal,
        linearTrackColor: AppColors.tealLight,
        circularTrackColor: Colors.transparent,
      ),
      iconTheme: const IconThemeData(color: AppColors.text, size: 22),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return AppColors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.teal;
          return AppColors.borderStrong;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.teal;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.white),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.teal;
          return AppColors.borderStrong;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.figtree(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.teal : AppColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? AppColors.teal : AppColors.muted,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.teal,
        unselectedLabelColor: AppColors.muted,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.figtree(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.figtree(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

    );
  }

  static TextTheme _textTheme(TextTheme base) {
    final body = GoogleFonts.figtreeTextTheme(base);

    TextStyle display(
      double size, {
      FontWeight weight = FontWeight.w700,
      Color? color,
      double height = 1.2,
      double letterSpacing = -0.5,
    }) {
      return GoogleFonts.figtree(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    TextStyle sans(
      double size, {
      FontWeight weight = FontWeight.w400,
      Color? color,
      double height = 1.45,
      double letterSpacing = 0,
    }) {
      return GoogleFonts.figtree(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return body.copyWith(
      displayLarge: display(34,
          color: AppColors.tealDark, height: 1.14, letterSpacing: -0.9),
      displayMedium: display(26,
          color: AppColors.tealDark, height: 1.18, letterSpacing: -0.6),
      displaySmall: display(22, height: 1.2, letterSpacing: -0.5),
      headlineLarge: display(28, height: 1.18, letterSpacing: -0.7),
      headlineMedium: display(23, height: 1.2, letterSpacing: -0.5),
      headlineSmall: display(20, height: 1.25, letterSpacing: -0.4),

      titleLarge: sans(18, weight: FontWeight.w700, height: 1.3,
          letterSpacing: -0.2),
      titleMedium: sans(16, weight: FontWeight.w700, height: 1.3,
          letterSpacing: -0.1),
      titleSmall: sans(14, weight: FontWeight.w600, height: 1.35),

      bodyLarge: sans(15, height: 1.5),
      bodyMedium: sans(14, height: 1.5),
      bodySmall: sans(12.5, color: AppColors.muted, height: 1.45),

      labelLarge: sans(14, weight: FontWeight.w700, height: 1.2),
      labelMedium: sans(12, weight: FontWeight.w600, height: 1.2),
      labelSmall: sans(11,
          weight: FontWeight.w600,
          color: AppColors.muted,
          height: 1.2,
          letterSpacing: 0.3),
    );
  }
}
