import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

/// Reads and writes the single local [Profile] to on-device storage.
///
/// Stored as one JSON string under a single key — the link list's
/// open-ended shape doesn't fit flat key-value pairs the way the old
/// fixed-field profile did, so this stores the whole Profile.toJson()
/// blob and decodes it back on load.
class ProfileStorage {
  static const _key = 'connect_profile_json';

  Future<Profile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const Profile();

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return Profile.fromJson(decoded);
    } catch (_) {
      // Corrupted or unreadable save data shouldn't crash the app on
      // launch — fall back to an empty profile, same as a first run.
      return const Profile();
    }
  }

  Future<void> save(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }
}