import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A slow, looping gradient drift behind the share card.
///
/// Subtle by design — the brief calls for "calm and elegant," not a
/// flashy animated backdrop. The gradient's two focal points drift in a
/// gentle ellipse over ~18 seconds.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({super.key});

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;

        final dx1 = math.cos(t);
        final dy1 = math.sin(t) * 0.6;
        final dx2 = math.cos(t + math.pi);
        final dy2 = math.sin(t + math.pi) * 0.5;

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(dx1 * 0.6, -0.4 + dy1),
                  radius: 1.1,
                  colors: [
                    scheme.primary.withOpacity(isDark ? 0.28 : 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(dx2 * 0.5, 0.5 + dy2),
                  radius: 1.0,
                  colors: [
                    scheme.tertiary.withOpacity(isDark ? 0.22 : 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
