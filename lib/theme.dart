import 'package:flutter/material.dart';

/// The house palette (see ../shared/THEME.md): a light-violet -> deep-violet gradient for bars, tabs and primary buttons on a
/// soft lilac background, with pink only as a small accent (badges, dots). Follows the system light/dark setting.
class AppColors {
  const AppColors._({required this.bg, required this.card, required this.text, required this.muted, required this.line, required this.placeholder});

  static const Color accent = Color(0xFFFF7AB8);
  static const Color violet = Color(0xFF7040E0);
  static const Color violetLight = Color(0xFF9A6BFF);
  static const LinearGradient grad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [violetLight, violet]);
  static const LinearGradient barGrad = grad;

  final Color bg, card, text, muted, line, placeholder;

  static const light = AppColors._(
      bg: Color(0xFFF6F4FA), card: Color(0xFFFFFFFF), text: Color(0xFF221C33), muted: Color(0xFF7A7390), line: Color(0xFFE6E1F0), placeholder: Color(0xFFEFE9FB));
  static const dark = AppColors._(
      bg: Color(0xFF14111D), card: Color(0xFF1E1A2B), text: Color(0xFFEDE9F7), muted: Color(0xFF9A93B0), line: Color(0xFF2E2942), placeholder: Color(0xFF241F35));

  static AppColors of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.violet, brightness: brightness)
        .copyWith(primary: AppColors.violet, secondary: AppColors.accent, surface: c.card, onSurface: c.text),
    scaffoldBackgroundColor: c.bg,
    appBarTheme: AppBarTheme(backgroundColor: c.bg, foregroundColor: c.text, elevation: 0, scrolledUnderElevation: 0),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.violet, foregroundColor: Colors.white),
    tabBarTheme: TabBarThemeData(labelColor: AppColors.violet, unselectedLabelColor: c.muted, indicatorColor: AppColors.violet),
  );
}

/// Gradient pill button, the main action on the sign-in screen.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(999)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: busy ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
