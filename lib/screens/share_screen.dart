import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/grainient_background.dart';
import 'edit_profile_screen.dart';

/// The app's launch screen and primary experience.
///
/// Shows the user's name/tagline plus a swipeable carousel of QR cards —
/// one per [LinkEntry] in their profile. Each card encodes a real,
/// standard URL (instagram.com/... or wa.me/...) that any camera app
/// opens natively. No loading state once the profile is available; the
/// calling code (main.dart) resolves the profile before this screen is
/// shown, so opening the app feels instant.
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
  }

  @override
  void dispose() {
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Edit profile',
              onPressed: _openEditProfile,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  child: profile.isEmpty
                      ? _EmptyState(onSetUp: _openEditProfile)
                      : _ShareCard(profile: profile),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _syncColors();
  }

  @override
  void didUpdateWidget(covariant _ShareCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Profile changed (e.g. returned from Edit) — re-sync colors
    // and clamp the page index in case a link was removed.
    if (oldWidget.profile != widget.profile) {
      final links = widget.profile.validLinks;
      if (_currentIndex >= links.length) {
        setState(() => _currentIndex = 0);
      }
      _syncColors();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Updates the global [GrainientBackground.colorNotifier] with the
  /// platform colors of the current link. Uses a post‑frame callback to
  /// avoid mutating the notifier during a build, which previously caused
  /// "setState() or markNeedsBuild() called during build" errors.
  void _syncColors() {
    final links = widget.profile.validLinks;
    final platform = links.isNotEmpty && _currentIndex < links.length
        ? links[_currentIndex].platform
        : null;
    // Always defer to after the frame to guarantee no listener triggers
    // a rebuild mid‑build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GrainientBackground.colorNotifier.value =
          backgroundColorsForPlatform(platform);
    });
  }

  @override
  Widget build(BuildContext context) {
    final links = widget.profile.validLinks;

    // No links yet but name/tagline exist: still show one static card
    // (no carousel needed for a single, link-less state).
    if (links.isEmpty) {
      return _SingleShareCard(
        profile: widget.profile,
        link: null,
        showSwipeHint: false,
      );
    }

    // Exactly one link: same single static card, just with that link's QR.
    // A carousel with one page swiping nowhere would be a pointless gesture.
    if (links.length == 1) {
      return _SingleShareCard(
        profile: widget.profile,
        link: links.first,
        showSwipeHint: false,
      );
    }

    // Multiple links: the ENTIRE card — name, tagline, QR, label, all of
    // it — becomes one page per link, and the whole physical card slides
    // as a unit when swiped. This is the actual carousel.
    return SizedBox(
      // A fixed height is required here: PageView needs a bounded height
      // to lay out its pages, and since each page is now a full card
      // (variable height depending on tagline presence, etc.), this picks
      // a height generous enough for the tallest realistic card.
      height: 560,
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
          const SizedBox(height: 20),
          _DotIndicator(count: links.length, activeIndex: _currentIndex),
        ],
      ),
    );
  }
}

/// One complete share card: name, tagline, QR, and label — everything
/// together as a single physical unit. When used inside the carousel,
/// the whole thing is one page that slides; outside the carousel
/// (zero or one link), it's just the static card.
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
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            profile.fullName.isEmpty ? 'Your Name' : profile.fullName,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (profile.tagline.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              profile.tagline.trim(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 36),
          if (link != null) _QrCard(link: link!),
          const SizedBox(height: 24),
          Text(
            link?.displayLabel ?? 'Scan to connect',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
            textAlign: TextAlign.center,
          ),
          if (link != null) ...[
            const SizedBox(height: 2),
            Text(
              link!.displayValue,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            showSwipeHint ? 'Swipe for more' : 'Scan to connect',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A single QR card — pure black on white, no color, no glow tint.
/// The link's real URL (instagram.com/... or wa.me/...) is encoded
/// directly, so any standard camera app opens it on scan.
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
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: QrImageView(
            data: link.toUrl(),
            version: QrVersions.auto,
            size: 204,
            gapless: false,
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

class _DotIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _DotIndicator({required this.count, required this.activeIndex});

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
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSetUp;

  const _EmptyState({required this.onSetUp});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 20),
          Text(
            'Set up your card',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Add your Instagram and WhatsApp\nto start sharing instantly.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onSetUp,
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }
}