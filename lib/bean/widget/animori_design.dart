import 'package:flutter/material.dart';
import 'package:animori/bean/widget/liquid_glass.dart';
import 'package:animori/utils/constants.dart';

const animoriMint = Color(0xFF348A78);

ThemeData buildAnimoriTheme({
  required Brightness brightness,
  String? fontFamily,
  Color? color,
  ColorScheme? colorScheme,
}) {
  final dark = brightness == Brightness.dark;
  final scheme =
      colorScheme ??
      ColorScheme.fromSeed(
        seedColor: color ?? animoriMint,
        brightness: brightness,
        surface: dark ? const Color(0xFF17242D) : const Color(0xFFF4F8F7),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface.withValues(alpha: 0.65),
      shape: shape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface.withValues(alpha: 0.65),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(18),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      backgroundColor: scheme.surface.withValues(alpha: 0.5),
      selectedColor: scheme.primaryContainer.withValues(alpha: 0.75),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      labelColor: scheme.onPrimaryContainer,
      unselectedLabelColor: scheme.onSurfaceVariant,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface.withValues(alpha: 0.96),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    progressIndicatorTheme: progressIndicatorTheme2024,
    sliderTheme: sliderTheme2024,
    pageTransitionsTheme: pageTransitionsTheme2024,
  );
}

/// Static ambient light keeps glass readable without continuous animation.
class AnimoriBackdrop extends StatelessWidget {
  const AnimoriBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF162D31), Color(0xFF1D2539), Color(0xFF30283D)]
              : const [Color(0xFFE1F3ED), Color(0xFFEDF0FC), Color(0xFFF6EAF2)],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.8, -0.6),
            radius: 1.2,
            colors: [
              Colors.white.withValues(alpha: dark ? 0.05 : 0.55),
              Colors.transparent,
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

class AnimoriPanel extends StatelessWidget {
  const AnimoriPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 28,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    radius: radius,
    blurSigma: 14,
    glassOpacity: 0.64,
    elevated: false,
    padding: padding,
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class AnimoriHeading extends StatelessWidget {
  const AnimoriHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.action,
  });
  final String eyebrow;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 2.5,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
