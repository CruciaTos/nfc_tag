import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Everything the UI needs to show an "update available" prompt.
class UpdateInfo {
  /// The latest version, with any leading "v" already stripped
  /// (e.g. GitHub tag "v1.3.0" becomes "1.3.0").
  final String version;

  /// Release notes (the release body), if any.
  final String? notes;

  /// Where "download"/"view" should take the user. This is the `.apk`
  /// asset's direct URL when the release publishes one, otherwise the
  /// release page itself.
  final String downloadUrl;

  /// True when [downloadUrl] points straight at an `.apk` file rather
  /// than the release page — lets the UI say "Download" vs "View release".
  final bool isDirectApk;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.isDirectApk,
    this.notes,
  });
}

/// Checks GitHub Releases for a build newer than the one currently
/// installed.
///
/// This queries the Releases API directly rather than a hand-maintained
/// `latest.json` — GitHub is already the source of truth for what's been
/// published, so there's nothing extra to keep in sync on every release.
class UpdateService {
  static const _owner = 'CruciaTos';
  static const _repo = 'nfc_tag';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  static const _releasesPageUrl =
      'https://github.com/$_owner/$_repo/releases/latest';

  /// Returns null when already up to date, offline, rate-limited, or on
  /// any other error. A failed check should never interrupt someone who
  /// just wants to share their card — it only ever adds a prompt, never
  /// blocks anything.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      // PackageInfo is the source of truth for "what's actually installed"
      // — it reads the real installed version rather than anything the
      // app might have cached from a previous check.
      final current = await PackageInfo.fromPlatform();

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').trim();
      final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latestVersion.isEmpty) return null;

      if (!_isNewer(latestVersion, current.version)) return null;

      final assets = (json['assets'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>();
      String? apkUrl;
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      return UpdateInfo(
        version: latestVersion,
        notes: (json['body'] as String?)?.trim(),
        downloadUrl: apkUrl ?? (json['html_url'] as String? ?? _releasesPageUrl),
        isDirectApk: apkUrl != null,
      );
    } catch (_) {
      // Offline, rate-limited, malformed response — none of these should
      // ever surface as an error to the user, so just skip the prompt.
      return null;
    }
  }

  /// Plain numeric, dot-separated version comparison ("1.10.0" > "1.9.0").
  /// Anything unparsable is treated as 0, so a malformed tag can never
  /// falsely claim to be newer than what's installed.
  bool _isNewer(String latest, String current) {
    List<int> parts(String v) => v
        .split('+') // drop any build-number suffix
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();

    final a = parts(latest);
    final b = parts(current);
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}