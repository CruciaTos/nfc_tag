import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/profile.dart';

/// Returns the gradient palette for a given platform.
/// Instagram now uses three colours: pink → purple → yellow.
List<Color> backgroundColorsForPlatform(LinkPlatform? platform) {
  switch (platform) {
    case LinkPlatform.instagram:
      return const [
        Color(0xFFD62976), // pink
        Color.fromARGB(255, 160, 58, 180), // purple
        Color.fromARGB(255, 89, 0, 255), // yellow
      ];
    case LinkPlatform.whatsapp:
      return const [Color(0xFF00A884), Color(0xFF075E54)];
    case LinkPlatform.website:
      // svayatta.in's own declared theme colour (#000b12) as the anchor,
      // graduating up through two deeper steel/slate blues — keeps the
      // site's moody, near-black identity rather than inventing a new one.
      return const [
        Color(0xFF000B12), // Svayatta's theme-color meta tag
        Color.fromARGB(255, 7, 13, 90), // steel blue
        Color.fromARGB(255, 25, 37, 201), // slate blue
      ];
    case null:
      return const [Color(0xFFCCCCCC), Color(0xFF444444)];
  }
}

/// A fluid animated background: wavy ribbons with a single blurred layer,
/// base gradient, animated film grain, and smooth colour transitions.
///
/// Platform colours are driven by [colorNotifier] — ShareScreen writes
/// to it when the visible QR card changes; the background listens and
/// cross‑fades to the new palette over ~900ms.
class GrainientBackground extends StatefulWidget {
  static final colorNotifier = ValueNotifier<List<Color>>(
    backgroundColorsForPlatform(null),
  );

  const GrainientBackground({super.key});

  @override
  State<GrainientBackground> createState() => _GrainientBackgroundState();
}

class _GrainientBackgroundState extends State<GrainientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _blobController;
  late final AnimationController _colorController;

  List<Color> _fromColors = backgroundColorsForPlatform(null);
  List<Color> _toColors = backgroundColorsForPlatform(null);

  Timer? _grainTimer;
  int _grainSeed = 0;

  @override
  void initState() {
    super.initState();

    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fromColors = GrainientBackground.colorNotifier.value;
    _toColors = GrainientBackground.colorNotifier.value;
    GrainientBackground.colorNotifier.addListener(_onColorsChanged);

    _grainTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _grainSeed = Random().nextInt(0xFFFFF));
    });
  }

  void _onColorsChanged() {
    final snapshot =
        _lerpColors(_fromColors, _toColors, _colorController.value);
    setState(() {
      _fromColors = snapshot;
      _toColors = GrainientBackground.colorNotifier.value;
    });
    _colorController.forward(from: 0);
  }

  /// Interpolates between two colour lists. If they differ in length,
  /// the missing indices use the last available colour.
  static List<Color> _lerpColors(List<Color> from, List<Color> to, double t) {
    final len = max(from.length, to.length);
    return List.generate(len, (i) {
      final a = i < from.length ? from[i] : from.last;
      final b = i < to.length ? to[i] : to.last;
      return Color.lerp(a, b, t) ?? a;
    });
  }

  List<Color> get _activeColors =>
      _lerpColors(_fromColors, _toColors, _colorController.value);

  @override
  void dispose() {
    GrainientBackground.colorNotifier.removeListener(_onColorsChanged);
    _blobController.dispose();
    _colorController.dispose();
    _grainTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_blobController, _colorController]),
      builder: (context, _) => CustomPaint(
        painter: _GrainientPainter(
          t: _blobController.value * 2 * pi,
          colors: _activeColors,
          grainSeed: _grainSeed,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _GrainientPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  final int grainSeed;

  /// Optional centre and radius of the card glow.
  /// When `null`, the painter uses the canvas centre and a default radius.
  final Offset? cardCenter;
  final double? cardRadius;

  const _GrainientPainter({
    required this.t,
    required this.colors,
    required this.grainSeed,
    this.cardCenter,
    this.cardRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Compute glow parameters (default if not supplied)
    final Offset center = cardCenter ?? Offset(size.width / 2, size.height / 2);
    final double radius = cardRadius ?? min(size.width, size.height) * 0.35;

    // 1. Base gradient – supports 2, 3 (or more) colours
    final baseGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: _generateStops(colors.length),
    );
    canvas.drawRect(
      rect,
      Paint()..shader = baseGradient.createShader(rect),
    );

    // ---- Soft glow behind the card ----
    _drawSoftGlow(canvas, center, radius);

    // 2. Blue grid (behind white grid)
    _drawBlueGrid(canvas, size);

    // 3. White grid
    _drawGrid(canvas, size);

    // 4. All ribbons drawn together into a single blurred layer
    _drawRibbonsWithSharedBlur(canvas, size);

    // 5. Film grain
    final rng = Random(grainSeed);
    _grain(canvas, size, rng, opacity: 0.022, count: 500);
    _grain(canvas, size, rng, opacity: 0.048, count: 250);
    _grain(canvas, size, rng, opacity: 0.085, count: 100);
  }

  /// Draws a soft, blurred white circle as a glow behind the card.
  void _drawSoftGlow(Canvas canvas, Offset center, double radius) {
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)   // subtle brightness
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45); // soft spread
    canvas.drawCircle(center, radius, glowPaint);
  }

  /// Creates evenly spaced stops for a given number of colours.
  List<double>? _generateStops(int count) {
    if (count <= 1) return null;
    return List.generate(count, (i) => i / (count - 1));
  }

  /// Returns the colour at a fraction (0…1) along a multi‑stop gradient.
  Color _colorAtFraction(double fraction) {
    if (colors.isEmpty) return Colors.transparent;
    if (colors.length == 1) return colors.first;

    // Clamp
    fraction = fraction.clamp(0.0, 1.0);

    // Find the two surrounding stops
    final double step = 1.0 / (colors.length - 1);
    final int lowerIndex = (fraction / step).floor();
    final int upperIndex = lowerIndex + 1;

    if (upperIndex >= colors.length) return colors.last;

    final double localT = (fraction - lowerIndex * step) / step;
    return Color.lerp(colors[lowerIndex], colors[upperIndex], localT)!;
  }

  /// Draws all wavy ribbons inside a [saveLayer] and applies a single blur
  /// to the whole layer.
  void _drawRibbonsWithSharedBlur(Canvas canvas, Size size) {
    final layerPaint = Paint()
      ..imageFilter = ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp);
    canvas.saveLayer(Offset.zero & size, layerPaint);

    const int ribbonCount = 5;
    for (int i = 0; i < ribbonCount; i++) {
      final double yFrac = 0.05 + (i / (ribbonCount - 1)) * 0.9;
      final Color ribbonColor = _colorAtFraction(yFrac);
      final double amplitude = size.height * 0.18;
      final double freq1 = 0.007 + 0.01 * sin(yFrac * 2.4);
      final double freq2 = 0.005 + 0.012 * cos(yFrac * 3.1);

      _ribbonPath(canvas, size, ribbonColor, yFrac, amplitude, freq1, freq2);
    }

    canvas.restore();
  }

  void _ribbonPath(
    Canvas canvas,
    Size size,
    Color color,
    double baseYRatio,
    double amplitude,
    double freq1,
    double freq2,
  ) {
    final path = Path();
    final double baseY = size.height * baseYRatio;

    for (double x = 0; x <= size.width; x += 8) {
      final y = baseY +
          amplitude * sin(x * freq1 + t * 0.7) +
          amplitude * 0.6 * cos(x * freq2 + t * 1.3);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 120
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBlueGrid(Canvas canvas, Size size) {
    const spacing = 60.0;
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.10)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    const spacing = 40.0;
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _grain(Canvas canvas, Size size, Random rng,
      {required double opacity, required int count}) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1.1;
    for (int i = 0; i < count; i++) {
      canvas.drawPoints(
        PointMode.points,
        [Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height)],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainientPainter old) => true;
}