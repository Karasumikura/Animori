import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:animori/bean/widget/animori_design.dart';

class AnimoriDiscoveryHero extends StatelessWidget {
  const AnimoriDiscoveryHero({super.key, this.onSearch});
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) => AnimoriPanel(
    padding: const EdgeInsets.all(28),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final theme = Theme.of(context);
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '为画质而来',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '让每一帧，\n都尽显细节。',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '自动检索可用来源，实测清晰度与码率。\n优先播放更高画质，把选择留给故事。',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onSearch ?? () => context.pushNamed('/search/'),
              icon: const Icon(Icons.search_rounded),
              label: const Text('寻找想看的番剧'),
            ),
          ],
        );
        final art = SizedBox(
          height: wide ? 250 : 140,
          child: CustomPaint(
            painter: _FramePainter(theme.colorScheme.primary),
            child: const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                size: 72,
                color: animoriMint,
              ),
            ),
          ),
        );
        return wide
            ? Row(
                children: [
                  Expanded(flex: 3, child: content),
                  const SizedBox(width: 30),
                  Expanded(flex: 2, child: art),
                ],
              )
            : content;
      },
    ),
  );
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 3; i >= 0; i--) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((i - 1) * 0.13);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.7,
        height: size.height * 0.65,
      );
      final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(26));
      canvas.drawRRect(
        rounded,
        Paint()..color = color.withValues(alpha: 0.045 + i * 0.01),
      );
      canvas.drawRRect(
        rounded,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => color != oldDelegate.color;
}
