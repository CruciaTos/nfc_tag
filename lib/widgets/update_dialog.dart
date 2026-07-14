import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';

/// Shows a themed "update available" sheet. Fire-and-forget — call it and
/// move on, it manages its own dismissal.
Future<void> showUpdateSheet(BuildContext context, UpdateInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black.withOpacity(0.94),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _UpdateSheet(info: info),
  );
}

class _UpdateSheet extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateSheet({required this.info});

  Future<void> _openDownload(BuildContext context) async {
    final uri = Uri.parse(info.downloadUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the download link')),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final notes = info.notes;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update available',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Version ${info.version}',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  notes,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _openDownload(context),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                info.isDirectApk ? 'Download update' : 'View release',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: double.infinity,
              child: Text('Later', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small "v1.2.3 · Check for updates" footer for settings-style screens.
/// Runs its own check on tap and reports back via SnackBar when there's
/// nothing new, so the control never feels like it did nothing.
class VersionFooter extends StatefulWidget {
  const VersionFooter({super.key});

  @override
  State<VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<VersionFooter> {
  String? _version;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    final update = await UpdateService().checkForUpdate();
    if (!mounted) return;
    setState(() => _checking = false);
    if (update != null) {
      showUpdateSheet(context, update);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("You're up to date")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_version != null)
          Text(
            'v$_version',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _checking ? null : _checkNow,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withOpacity(0.6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                )
              : const Text('Check for updates', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}