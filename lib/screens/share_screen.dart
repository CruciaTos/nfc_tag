import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
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
        centerTitle: true,
        title: const _BrandMark(),
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

/// The company wordmark shown at the top of the Share screen — a sleek,
/// Dynamic Island‑style pill that carries the brand lockup with quiet
/// confidence.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'DZEN',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                height: 1,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
            TextSpan(
              text: '  SVAYATTA',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                height: 1,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
          ],
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

  /// The carousel page to open on, based on the user's chosen Startup QR
  /// (Profile.defaultLinkId). Falls back to the first card (index 0) when
  /// no default is set or the saved id no longer matches a saved link —
  /// this is the pre-existing behavior, left untouched as the fallback.
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
    // Solid black container replaces GlassCard
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 44),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
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
        ],
      ),
    );
  }
}

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
    // Solid black container replaces GlassCard
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
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