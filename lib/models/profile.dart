/// A single shareable link — one entry in the user's QR carousel.
///
/// [platform] drives both the QR payload's URL shape and the icon/label
/// shown on its card. [label] is optional and lets a user distinguish
/// two entries of the same platform (e.g. "Insta — Personal" vs
/// "Insta — Photography").
enum LinkPlatform { instagram, whatsapp, website }

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
      case LinkPlatform.website:
        // Hardcoded — this entry only ever points at one destination, so
        // there's nothing for the user to type and nothing that can go
        // stale in [value].
        return 'https://svayatta.in';
    }
  }

  String get displayLabel {
    if (label != null && label!.trim().isNotEmpty) return label!.trim();
    switch (platform) {
      case LinkPlatform.instagram:
        return 'Instagram';
      case LinkPlatform.whatsapp:
        return 'WhatsApp';
      case LinkPlatform.website:
        return 'Svayatta';
    }
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
      case LinkPlatform.website:
        return 'svayatta.in';
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

  /// The [LinkEntry.id] the user picked as their "Startup QR" — the card
  /// shown first on launch, before any swiping. Null means no explicit
  /// choice has been made yet, in which case callers fall back to the
  /// first valid link (the pre-existing default behavior).
  final String? defaultLinkId;

  const Profile({
    this.fullName = '',
    this.tagline = '',
    this.photoPath,
    this.links = const [],
    this.defaultLinkId,
  });

  bool get isEmpty =>
      fullName.isEmpty && links.where((l) => l.isValid).isEmpty;

  List<LinkEntry> get validLinks => links.where((l) => l.isValid).toList();

  /// The link the app should open to, resolved against [validLinks].
  /// Falls back to the first valid link (or null, if there are none)
  /// whenever no default is set or the saved id no longer matches an
  /// existing link — e.g. it was deleted after being chosen.
  LinkEntry? get defaultLink {
    final links = validLinks;
    if (links.isEmpty) return null;
    if (defaultLinkId == null) return links.first;
    return links.firstWhere(
      (l) => l.id == defaultLinkId,
      orElse: () => links.first,
    );
  }

  Profile copyWith({
    String? fullName,
    String? tagline,
    String? photoPath,
    List<LinkEntry>? links,
    String? defaultLinkId,
  }) {
    return Profile(
      fullName: fullName ?? this.fullName,
      tagline: tagline ?? this.tagline,
      photoPath: photoPath ?? this.photoPath,
      links: links ?? this.links,
      defaultLinkId: defaultLinkId ?? this.defaultLinkId,
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'tagline': tagline,
        'photoPath': photoPath,
        'links': links.map((l) => l.toJson()).toList(),
        'defaultLinkId': defaultLinkId,
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
      defaultLinkId: json['defaultLinkId'] as String?,
    );
  }
}