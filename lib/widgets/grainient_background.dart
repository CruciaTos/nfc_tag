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

/// A fluid animated background: three gradient blobs moving on
/// non-repeating Lissajous paths, with animated film grain on top,
/// and smooth color transitions when the platform changes.
///
/// Platform colors are driven by [colorNotifier] — ShareScreen writes
/// to it when the visible QR card changes; the background listens and
/// cross-fades to the new palette over ~900ms.
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
  // Drives all three blob positions — one continuous loop.
  late final AnimationController _blobController;

  // Drives color cross-fade when the platform changes.
  // Runs once (0→1) on each platform switch, then idles.
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

    // Grain refreshes at ~10fps — fast enough to read as motion,
    // slow enough not to spike the GPU behind every screen constantly.
    _grainTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _grainSeed = Random().nextInt(0xFFFFF));
    });
  }

  void _onColorsChanged() {
    // Snapshot wherever we currently are mid-transition so the new
    // cross-fade always starts from the actual rendered state, not
    // from a stale "from" value if the user swipes quickly.
    final snapshot = _lerpColors(_fromColors, _toColors, _colorController.value);
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
    // FIXED: corrected AnimatedBuilder → AnimatedBuilder (the standard widget)
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

  // Irrational frequency ratios — golden ratio, √2, √3.
  // These ensure the three blobs never fall back into a visible
  // repeating pattern relative to each other over normal usage time.
  static const _phi  = 1.6180339887; // golden ratio
  static const _sq2  = 1.4142135623; // √2
  static const _sq3  = 1.7320508075; // √3

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = Colors.black);

    final c0 = colors[0];
    final c1 = colors.length > 1 ? colors[1] : colors[0];
    final cMid = Color.lerp(c0, c1, 0.5)!;

    // --- Blob 0 ---
    // Large, slow. Primary color.
    // Path: two cosine terms on x, two sine on y, using t and φt.
    // The offset phases (1.0, 0.7) ensure the path isn't axis-aligned.
    _blob(canvas, size, rect,
      x: w * (0.5 + 0.38 * cos(t)           + 0.14 * cos(_phi * t + 1.0)),
      y: h * (0.42 + 0.26 * sin(t)           + 0.10 * sin(_sq2  * t + 0.7)),
      radiusPx: w * 0.82,
      color: c0.withOpacity(0.38),
    );

    // --- Blob 1 ---
    // Medium. Secondary color. Drifts counter to blob 0 (phase shift of 2.1).
    // Uses φt and √3t — irrational relative to blob 0's t and √2t.
    _blob(canvas, size, rect,
      x: w * (0.5 + 0.30 * cos(_phi * t + 2.1) + 0.18 * cos(_sq3 * t)),
      y: h * (0.62 + 0.30 * sin(_sq2  * t + 1.4) + 0.12 * sin(t   + 2.5)),
      radiusPx: w * 0.68,
      color: c1.withOpacity(0.30),
    );

    // --- Blob 2 ---
    // Smaller, fastest path. Blended color. Uses √3t and √2t — both
    // irrational relative to each other and the two blobs above.
    _blob(canvas, size, rect,
      x: w * (0.5 + 0.22 * cos(_sq3 * t + 3.7) + 0.16 * cos(_sq2  * t + 1.2)),
      y: h * (0.5 + 0.24 * sin(_phi * t + 0.9) + 0.14 * sin(_sq3  * t + 3.1)),
      radiusPx: w * 0.54,
      color: cMid.withOpacity(0.22),
    );

    // Film grain — three passes at increasing opacity, decreasing density.
    // Only the seed changes (at ~10fps via timer), not the point count.
    final rng = Random(grainSeed);
    _grain(canvas, size, rng, opacity: 0.022, count: 700);
    _grain(canvas, size, rng, opacity: 0.048, count: 380);
    _grain(canvas, size, rng, opacity: 0.085, count: 150);
  }

  void _blob(
    Canvas canvas,
    Size size,
    Rect rect, {
    required double x,
    required double y,
    required double radiusPx,
    required Color color,
  }) {
    // Convert pixel center to normalized Alignment space (-1..1),
    // and pixel radius to RadialGradient's "fraction of shorter side" units.
    final shorter = min(size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (x / size.width)  * 2 - 1,
            (y / size.height) * 2 - 1,
          ),
          colors: [color, Colors.transparent],
          radius: radiusPx / shorter,
        ).createShader(rect),
    );
  }

  void _grain(Canvas canvas, Size size, Random rng,
      {required double opacity, required int count}) {
    canvas.drawPoints(
      PointMode.points,
      List.generate(
        count,
        (_) => Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
      ),
      Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..strokeWidth = 1.1,
    );
  }

  // Always repaint — the blob position changes every frame from _blobController.
  @override
  bool shouldRepaint(covariant _GrainientPainter old) => true;
}