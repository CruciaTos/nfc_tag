import 'package:flutter/material.dart';
import 'models/profile.dart';
import 'services/profile_storage.dart';
import 'screens/share_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/grainient_background.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConnectApp());
}

/// Root widget. Loads the saved [Profile] from local storage before
/// building the real UI, so ShareScreen never has to render a loading
/// or splash state — by the time MaterialApp paints, the profile is
/// already resolved (or confirmed empty, for first-run).
class ConnectApp extends StatefulWidget {
  const ConnectApp({super.key});

  @override
  State<ConnectApp> createState() => _ConnectAppState();
}

class _ConnectAppState extends State<ConnectApp> {
  final _storage = ProfileStorage();
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final loaded = await _storage.load();
    setState(() => _profile = loaded);
  }

  Future<void> _handleProfileChanged(Profile updated) async {
    setState(() => _profile = updated);
    await _storage.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // The grain/gradient background lives here, not inside individual
      // screens — MaterialApp.builder wraps every route Flutter pushes,
      // so this stays "global" automatically as new screens get added,
      // rather than needing to be copy-pasted into each Scaffold.
      builder: (context, child) {
        return Stack(
          children: [
            const Positioned.fill(child: GrainientBackground()),
            if (child != null) child,
          ],
        );
      },
      // Fixed black-and-white design — no light mode, no system theme
      // switching. Always dark by design, not by following the OS.
      home: _profile == null
          ? const _NativeSplashHandoff()
          : ShareScreen(
              profile: _profile!,
              onProfileChanged: _handleProfileChanged,
            ),
    );
  }
}

/// A transparent, momentary handoff widget shown only during the brief
/// window between process start and the local profile load completing.
///
/// This is NOT a splash/loading screen in the product sense — it renders
/// nothing visible (just the theme's background color) and typically
/// exists for a few milliseconds, since SharedPreferences reads are fast.
/// Android's native splash (configured in the launch theme, not here)
/// covers the true cold-start gap before Flutter's first frame.
class _NativeSplashHandoff extends StatelessWidget {
  const _NativeSplashHandoff();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}