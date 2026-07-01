/// A single shareable link — one entry in the user's QR carousel.
///
/// [platform] drives both the QR payload's URL shape and the icon/label
/// shown on its card. [label] is optional and lets a user distinguish
/// two entries of the same platform (e.g. "Insta — Personal" vs
/// "Insta — Photography").
enum LinkPlatform { instagram, whatsapp }

class LinkEntry {
  final String id;
  final LinkPlatform platform;
  final String value; // Instagram handle, or WhatsApp phone number
  final String? label;

  const LinkEntry({
    required this.id,
    required this.platform,
    required this.value,
    this.label,
  });

  bool get isValid => value.trim().isNotEmpty;

  /// The real, standard URL this entry resolves to. A camera app or any
  /// QR scanner opens these natively — no custom app/scheme required.
  String toUrl() {
    final v = value.trim();
    switch (platform) {
      case LinkPlatform.instagram:
        // Accept a raw handle ("@name" or "name") or a full URL already.
        final handle = v.startsWith('http')
            ? v
            : 'https://instagram.com/${v.replaceFirst('@', '')}';
        return handle;
      case LinkPlatform.whatsapp:
        // wa.me expects digits only, no symbols/spaces/leading +.
        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
        return 'https://wa.me/$digits';
    }
  }

  String get displayLabel {
    if (label != null && label!.trim().isNotEmpty) return label!.trim();
    return platform == LinkPlatform.instagram ? 'Instagram' : 'WhatsApp';
  }

  /// A human-readable form of the actual handle/number — shown alongside
  /// [displayLabel] so a user with multiple links of the same platform
  /// (or multiple cards in general) can tell which QR is which without
  /// scanning it.
  String get displayValue {
    final v = value.trim();
    switch (platform) {
      case LinkPlatform.instagram:
        if (v.startsWith('http')) {
          // Strip the protocol/www for a cleaner read, e.g.
          // "instagram.com/name" instead of "https://www.instagram.com/name".
          return v.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
        }
        return '@${v.replaceFirst('@', '')}';
      case LinkPlatform.whatsapp:
        return v;
    }
  }

  LinkEntry copyWith({
    LinkPlatform? platform,
    String? value,
    String? label,
  }) {
    return LinkEntry(
      id: id,
      platform: platform ?? this.platform,
      value: value ?? this.value,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform.name,
        'value': value,
        'label': label,
      };

  factory LinkEntry.fromJson(Map<String, dynamic> json) {
    return LinkEntry(
      id: json['id'] as String,
      platform: LinkPlatform.values.firstWhere(
        (p) => p.name == json['platform'],
        orElse: () => LinkPlatform.instagram,
      ),
      value: json['value'] as String? ?? '',
      label: json['label'] as String?,
    );
  }
}

/// The user's local profile.
///
/// Stored entirely on-device. No accounts, no sync. [links] is an
/// open-ended, user-ordered list — each entry becomes one swipeable QR
/// card on the Share screen.
class Profile {
  final String fullName;
  final String tagline;
  final String? photoPath;
  final List<LinkEntry> links;

  const Profile({
    this.fullName = '',
    this.tagline = '',
    this.photoPath,
    this.links = const [],
  });

  bool get isEmpty =>
      fullName.isEmpty && links.where((l) => l.isValid).isEmpty;

  List<LinkEntry> get validLinks => links.where((l) => l.isValid).toList();

  Profile copyWith({
    String? fullName,
    String? tagline,
    String? photoPath,
    List<LinkEntry>? links,
  }) {
    return Profile(
      fullName: fullName ?? this.fullName,
      tagline: tagline ?? this.tagline,
      photoPath: photoPath ?? this.photoPath,
      links: links ?? this.links,
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'tagline': tagline,
        'photoPath': photoPath,
        'links': links.map((l) => l.toJson()).toList(),
      };

  factory Profile.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['links'] as List<dynamic>? ?? [];
    return Profile(
      fullName: json['fullName'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
      links: rawLinks
          .map((e) => LinkEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}