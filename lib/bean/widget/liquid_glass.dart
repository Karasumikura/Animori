import 'dart:ui';

import 'package:flutter/material.dart';

/// Animori 玻璃容器：实时背景模糊 + 半透明体积渐变 + 高光边缘 + 漂浮阴影。
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 28,
    this.blurSigma = 22,
    this.tint,
    this.glassOpacity = 0.55,
    this.padding = const EdgeInsets.all(16),
    this.elevated = true,
    this.specular = true,
  });

  final Widget child;
  final double radius;
  final double blurSigma;

  /// 玻璃基调色；null 时按主题自动取白/深灰。
  final Color? tint;
  final double glassOpacity;
  final EdgeInsetsGeometry padding;

  /// 是否带漂浮阴影。
  final bool elevated;

  /// 是否绘制顶部镜面高光。
  final bool specular;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final base = tint ?? (dark ? const Color(0xFF1E303B) : Colors.white);
    final corner = BorderRadius.circular(radius);

    final body = Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: const SizedBox.expand(),
          ),
        ),
        // 体积渐变：顶部偏亮、底部偏暗，营造玻璃厚度。
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: dark ? 0.10 : 0.22),
                    base,
                  ).withValues(alpha: glassOpacity),
                  base.withValues(alpha: glassOpacity * (dark ? 0.72 : 0.62)),
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: dark ? 0.18 : 0.06),
                    base,
                  ).withValues(alpha: glassOpacity * 0.9),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        if (specular)
          Positioned.fill(
            child: CustomPaint(painter: _GlassEdgePainter(radius: radius)),
          ),
        Padding(padding: padding, child: child),
      ],
    );

    final clipped = ClipRRect(borderRadius: corner, child: body);
    if (!elevated) return clipped;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corner,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.16),
            blurRadius: radius * 0.9,
            spreadRadius: 0,
            offset: Offset(0, radius * 0.35),
          ),
        ],
      ),
      child: clipped,
    );
  }
}

/// 玻璃边缘：整体一圈亮边，顶部一条更强的镜面高光。
class _GlassEdgePainter extends CustomPainter {
  _GlassEdgePainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.04),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, edge);

    // 顶部内高光：一条两端淡出的亮线。
    final topY = 1.0;
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.7),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, topY, size.width, 2));
    final path = Path()
      ..moveTo(radius * 0.9, topY + 0.6)
      ..lineTo(size.width - radius * 0.9, topY + 0.6);
    canvas.drawPath(path, highlight);
  }

  @override
  bool shouldRepaint(covariant _GlassEdgePainter old) => old.radius != radius;
}

/// 液态玻璃胶囊按钮，按下时整体变亮并轻微收缩。
class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.radius = 22,
    this.tone,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double radius;

  /// 强调色；非空时按钮带该色淡彩。
  final Color? tone;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final colors = Theme.of(context).colorScheme;
    final accent = widget.tone ?? colors.primary;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: LiquidGlass(
          radius: widget.radius,
          elevated: !_down,
          specular: true,
          tint: Color.alphaBlend(accent.withValues(alpha: 0.18), Colors.white),
          glassOpacity: enabled ? 0.7 : 0.4,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 19,
                  color: enabled ? accent : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: enabled ? accent : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
