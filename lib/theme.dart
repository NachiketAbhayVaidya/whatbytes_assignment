import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kPrimary = Color(0xFF6C63FF);

/// App-specific colors that differ between light and dark mode.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.card,
    required this.field,
    required this.ink,
    required this.muted,
    required this.border,
    required this.header,
  });

  final Color bg, card, field, ink, muted, border, header;

  static const light = AppColors(
    bg: Color(0xFFF6F7FB),
    card: Colors.white,
    field: Color(0xFFF6F7FB),
    ink: Color(0xFF2D2F55),
    muted: Color(0x73000000),
    border: Color(0xFFEEEEEE),
    header: Color(0xFF7F7BEB),
  );

  static const dark = AppColors(
    bg: Color(0xFF14151F),
    card: Color(0xFF1E2030),
    field: Color(0xFF282B40),
    ink: Color(0xFFEDEEFF),
    muted: Color(0x99FFFFFF),
    border: Color(0xFF2E3147),
    header: Color(0xFF47448C),
  );

  @override
  AppColors copyWith({Color? bg, Color? card, Color? field, Color? ink, Color? muted, Color? border, Color? header}) =>
      AppColors(
        bg: bg ?? this.bg,
        card: card ?? this.card,
        field: field ?? this.field,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        border: border ?? this.border,
        header: header ?? this.header,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      field: Color.lerp(field, other.field, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      header: Color.lerp(header, other.header, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary, brightness: brightness);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    extensions: [colors],
    scaffoldBackgroundColor: colors.card,
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(bodyColor: colors.ink, displayColor: colors.ink),
    appBarTheme: AppBarTheme(backgroundColor: colors.card, surfaceTintColor: Colors.transparent, foregroundColor: colors.ink),
    dialogTheme: DialogThemeData(backgroundColor: colors.card, surfaceTintColor: Colors.transparent),
    popupMenuTheme: PopupMenuThemeData(color: colors.card, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
  );
}

/// Remembers the user's light/dark choice (defaults to following the system).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);
  static final instance = ThemeController._();
  static const _key = 'themeMode';

  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {}
  }

  Future<void> set(ThemeMode mode) async {
    value = mode;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, mode.name);
    } catch (_) {}
  }
}
