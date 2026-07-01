import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/profile.dart';

/// Returns the two-color gradient palette for a given platform.
/// These are called by ShareScreen when the active card changes.
List<Color> backgroundColorsForPlatform(LinkPlatform? platform) {
  switch (platform) {
    case LinkPlatform.instagram:
      return const [Color(0xFFD62976), Color(0xFF833AB4)]; // pink → purple
    case LinkPlatform.whatsapp:
      return const [Color(0xFF00A884), Color(0xFF075E54)]; // bright green → deep teal
    case null:
      return const [Color(0xFFCCCCCC), Color(0xFF444444)]; // neutral white/gray
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

  const _GrainientPainter({
    required this.t,
    required this.colors,
    required this.grainSeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c0 = colors[0];
    final c1 = colors.length > 1 ? colors[1] : colors[0];

    // 1. Base gradient – ensures no black is visible
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c0, c1],
        ).createShader(rect),
    );

    // 2. Blue grid (behind white grid)
    _drawBlueGrid(canvas, size);

    // 3. White grid
    _drawGrid(canvas, size);

    // 4. All ribbons drawn together into a single blurred layer
    _drawRibbonsWithSharedBlur(canvas, size, c0, c1);

    // 5. Film grain (light performance hit, kept as-is)
    final rng = Random(grainSeed);
    _grain(canvas, size, rng, opacity: 0.022, count: 500);   // slightly reduced
    _grain(canvas, size, rng, opacity: 0.048, count: 250);
    _grain(canvas, size, rng, opacity: 0.085, count: 100);
  }

  /// Draws all wavy ribbons inside a [saveLayer] and applies a single blur
  /// to the whole layer. This is **much** cheaper than blurring each ribbon.
  void _drawRibbonsWithSharedBlur(Canvas canvas, Size size, Color c0, Color c1) {
    final layerPaint = Paint()
      ..imageFilter = ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp);
    canvas.saveLayer(Offset.zero & size, layerPaint);

    // Draw 5 thick, high‑opacity ribbons without any per‑ribbon blur
    const int ribbonCount = 5;
    for (int i = 0; i < ribbonCount; i++) {
      final double yFrac = 0.05 + (i / (ribbonCount - 1)) * 0.9;
      final Color ribbonColor = Color.lerp(c0, c1, yFrac)!;
      final double amplitude = size.height * 0.18;  // bigger waves because fewer ribbons
      final double freq1 = 0.007 + 0.01 * sin(yFrac * 2.4);
      final double freq2 = 0.005 + 0.012 * cos(yFrac * 3.1);

      _ribbonPath(canvas, size, ribbonColor, yFrac, amplitude, freq1, freq2);
    }

    canvas.restore();
  }

  /// Draws a single ribbon **without** any blur – the whole layer will be blurred.
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

    // Step of 8 – with the layer blur this remains smooth
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

    // High opacity, thick stroke – the layer blur softens it
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 120
        ..strokeCap = StrokeCap.round,
      // No maskFilter here – blur is applied by the saveLayer
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