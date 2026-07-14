import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/profile.dart';
import '../services/nfc_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/grainient_background.dart';
import '../widgets/update_dialog.dart';
import 'edit_profile_screen.dart';

const double _cardRadius = 34.0;

class ShareScreen extends StatefulWidget {
  final Profile profile;
  final ValueChanged<Profile> onProfileChanged;

  const ShareScreen({
    super.key,
    required this.profile,
    required this.onProfileChanged,
  });

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  final NfcService _nfcService = NfcService();
  bool _isWritingNfc = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
    );
    _entrance.forward();
    // Checked once per app open, after the first frame so the share card
    // is already visible before any prompt could appear on top of it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCheckForUpdate());
  }

  Future<void> _maybeCheckForUpdate() async {
    final info = await UpdateService().checkForUpdate();
    if (info != null && mounted) {
      showUpdateSheet(context, info);
    }
  }

  @override
  void dispose() {
    _nfcService.stopSession();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<Profile>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: EditProfileScreen(profile: widget.profile),
        ),
      ),
    );
    if (updated != null) {
      widget.onProfileChanged(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.6),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'DZEN',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.white),
              tooltip: 'Edit profile',
              onPressed: _openEditProfile,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.08),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ScaleTransition(
                        scale: _scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            profile.isEmpty
                                ? _EmptyState(onSetUp: _openEditProfile)
                                : _ShareCard(profile: profile),
                            if (!profile.isEmpty && profile.defaultLink != null)
                              _NfcWriteButton(
                                isWriting: _isWritingNfc,
                                onPressed: _writeToNfc,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _writeToNfc() async {
    final link = widget.profile.defaultLink;
    if (link == null) return;

    setState(() => _isWritingNfc = true);

    final error = await _nfcService.writeProfileUrl(link.toUrl());

    if (!mounted) return;
    setState(() => _isWritingNfc = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('NFC tag written successfully!'),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _ShareCard extends StatefulWidget {
  final Profile profile;
  const _ShareCard({required this.profile});
  @override
  State<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<_ShareCard> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _defaultIndexFor(widget.profile);
    _pageController = PageController(
      viewportFraction: 1.0,
      initialPage: _currentIndex,
    );
    _syncColors();
  }

  int _defaultIndexFor(Profile profile) {
    final links = profile.validLinks;
    if (links.isEmpty) return 0;
    final defaultId = profile.defaultLinkId;
    if (defaultId == null) return 0;
    final index = links.indexWhere((l) => l.id == defaultId);
    return index == -1 ? 0 : index;
  }

  @override
  void didUpdateWidget(covariant _ShareCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      final links = widget.profile.validLinks;
      if (_currentIndex >= links.length) {
        setState(() => _currentIndex = 0);
      }
      if (oldWidget.profile.defaultLinkId != widget.profile.defaultLinkId) {
        final target = _defaultIndexFor(widget.profile);
        if (target != _currentIndex) {
          setState(() => _currentIndex = target);
          if (_pageController.hasClients) {
            _pageController.jumpToPage(target);
          }
        }
      }
      _syncColors();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _syncColors() {
    final links = widget.profile.validLinks;
    final platform = links.isNotEmpty && _currentIndex < links.length
        ? links[_currentIndex].platform
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GrainientBackground.colorNotifier.value =
          backgroundColorsForPlatform(platform);
    });
  }

  @override
  Widget build(BuildContext context) {
    final links = widget.profile.validLinks;

    if (links.isEmpty) {
      return _SingleShareCard(
        profile: widget.profile,
        link: null,
        showSwipeHint: false,
      );
    }

    if (links.length == 1) {
      return _SingleShareCard(
        profile: widget.profile,
        link: links.first,
        showSwipeHint: false,
      );
    }

    return SizedBox(
      height: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: links.length,
              onPageChanged: (i) {
                setState(() => _currentIndex = i);
                _syncColors();
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _SingleShareCard(
                    profile: widget.profile,
                    link: links[index],
                    showSwipeHint: true,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _ModernPageIndicator(count: links.length, activeIndex: _currentIndex),
        ],
      ),
    );
  }
}

class _SingleShareCard extends StatelessWidget {
  final Profile profile;
  final LinkEntry? link;
  final bool showSwipeHint;

  const _SingleShareCard({
    required this.profile,
    required this.link,
    required this.showSwipeHint,
  });

  @override
  Widget build(BuildContext context) {
    return _GradientWindowCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tagline first (top)
          if (profile.tagline.trim().isNotEmpty)
            Text(
              profile.tagline.trim(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.60),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          // Name second (bottom)
          Text(
            profile.fullName.isEmpty ? 'Your Name' : profile.fullName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          if (link != null) _QrCard(link: link!),
          const SizedBox(height: 14),
          if (link != null)
            _PlatformLabel(platform: link!.displayLabel),
          if (link != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                link!.displayValue,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.70),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Text(
              'Scan to connect',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

/// Displays the platform name as centered text.
class _PlatformLabel extends StatelessWidget {
  final String platform;
  const _PlatformLabel({required this.platform});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        platform,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GradientWindowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GradientWindowCard({
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 60,
            offset: const Offset(0, 25),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Stack(
          children: [
            const Positioned.fill(child: GrainientBackground()),
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.8,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_cardRadius),
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.85,
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.08),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: _GridOverlay()),
            const Positioned.fill(child: _NoiseOverlay()),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid overlay
// ---------------------------------------------------------------------------

class _GridOverlay extends StatefulWidget {
  const _GridOverlay();
  @override
  _GridOverlayState createState() => _GridOverlayState();
}

class _GridOverlayState extends State<_GridOverlay> {
  late final _GridPainter _painter;
  @override
  void initState() {
    super.initState();
    _painter = _GridPainter();
  }
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _painter);
  }
}

class _GridPainter extends CustomPainter {
  static const double _spacing = 40.0;
  static const double _lineWidth = 0.5;
  static final _lineColor = Colors.white.withOpacity(0.2);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _lineColor
      ..strokeWidth = _lineWidth
      ..style = PaintingStyle.stroke;

    double x = 0;
    while (x <= size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      x += _spacing;
    }

    double y = 0;
    while (y <= size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += _spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Noise overlay
// ---------------------------------------------------------------------------

class _NoiseOverlay extends StatefulWidget {
  const _NoiseOverlay();
  @override
  _NoiseOverlayState createState() => _NoiseOverlayState();
}

class _NoiseOverlayState extends State<_NoiseOverlay> {
  late final _NoisePainter _painter;
  @override
  void initState() {
    super.initState();
    _painter = _NoisePainter();
  }
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _painter);
  }
}

class _NoisePainter extends CustomPainter {
  List<Offset>? _points;
  final _random = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    if (_points == null) {
      _points = List.generate(
        1200,
        (_) => Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
      );
    }

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    for (final point in _points!) {
      canvas.drawCircle(point, 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// QR card
// ---------------------------------------------------------------------------

class _QrCard extends StatelessWidget {
  final LinkEntry link;
  const _QrCard({required this.link});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(link.id),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.85 + (0.15 * value.clamp(0, 1)),
            child: Opacity(opacity: value.clamp(0, 1), child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: QrImageView(
            data: link.toUrl(),
            version: QrVersions.auto,
            size: 280,
            gapless: true,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modern page indicator
// ---------------------------------------------------------------------------

class _ModernPageIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;
  const _ModernPageIndicator({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// NFC write button
// ---------------------------------------------------------------------------

class _NfcWriteButton extends StatelessWidget {
  final bool isWriting;
  final VoidCallback onPressed;

  const _NfcWriteButton({
    required this.isWriting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isWriting
                ? Colors.white.withOpacity(0.4)
                : Colors.white.withOpacity(0.15),
            width: 1,
          ),
          color: Colors.white.withOpacity(isWriting ? 0.08 : 0.04),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isWriting ? null : onPressed,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withOpacity(0.08),
            highlightColor: Colors.white.withOpacity(0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWriting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.nfc, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    isWriting ? 'Tap your NFC tag…' : 'Write to NFC Tag',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(isWriting ? 0.7 : 1.0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onSetUp;
  const _EmptyState({required this.onSetUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 20),
          const Text(
            'Set up your card',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Add your Instagram, WhatsApp, or Website\nto start sharing instantly.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onSetUp,
            child: const Text('Get Started', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}