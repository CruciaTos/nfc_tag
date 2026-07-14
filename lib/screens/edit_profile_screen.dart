import 'dart:io';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/update_dialog.dart';

class EditProfileScreen extends StatefulWidget {
  final Profile profile;
  const EditProfileScreen({super.key, required this.profile});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _taglineController;
  late List<LinkEntry> _links;
  String? _photoPath;
  String? _defaultLinkId;
  bool _isPickingImage = false;

  List<LinkEntry> _normalizeLinkIds(List<LinkEntry> links) {
    final normalized = <LinkEntry>[];
    final seenIds = <String>{};
    for (final link in links) {
      var safeId = link.id.trim();
      if (safeId.isEmpty || seenIds.contains(safeId)) {
        var candidate = 0;
        while (seenIds.contains('link_$candidate')) {
          candidate++;
        }
        safeId = 'link_$candidate';
      }
      seenIds.add(safeId);
      normalized.add(LinkEntry(
        id: safeId,
        platform: link.platform,
        value: link.value,
        label: link.label,
      ));
    }
    return normalized;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _taglineController = TextEditingController(text: widget.profile.tagline);
    _links = _normalizeLinkIds(List.of(widget.profile.links));
    _photoPath = widget.profile.photoPath;
    _defaultLinkId = widget.profile.defaultLinkId;
    if (_defaultLinkId != null &&
        !_links.any((link) => link.id == _defaultLinkId)) {
      _defaultLinkId = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  List<LinkEntry> get _validLinks => _links.where((l) => l.isValid).toList();

  Profile _buildProfile() {
    final validIds = _validLinks.map((l) => l.id).toSet();
    return Profile(
      fullName: _nameController.text.trim(),
      tagline: _taglineController.text.trim(),
      photoPath: _photoPath,
      links: _links,
      defaultLinkId:
          validIds.contains(_defaultLinkId) ? _defaultLinkId : null,
    );
  }

  Future<void> _pickPhoto() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;
      final docsDir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final savedPath = '${docsDir.path}/connect_profile_photo.$ext';
      await File(picked.path).copy(savedPath);
      if (!mounted) return;
      setState(() => _photoPath = savedPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  String _nextLinkId() {
    final existingIds = _links.map((link) => link.id).toSet();
    var candidate = 0;
    while (existingIds.contains('link_$candidate')) {
      candidate++;
    }
    return 'link_$candidate';
  }

  Future<void> _addLink() async {
    final newLink = await showModalBottomSheet<LinkEntry>(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.92),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _AddLinkSheet(id: _nextLinkId()),
    );
    if (newLink != null) {
      setState(() => _links.add(newLink));
    }
  }

  void _removeLink(String id) {
    setState(() {
      _links.removeWhere((l) => l.id == id);
      if (_defaultLinkId == id) {
        _defaultLinkId = null;
      }
    });
  }

  void _handleSetDefault(String id) {
    final wasDefault = _defaultLinkId == id;
    setState(() => _defaultLinkId = wasDefault ? null : id);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            wasDefault
                ? 'Startup QR cleared — using the first link automatically'
                : 'Set as your Startup QR',
          ),
        ),
      );
  }

  void _save() {
    Navigator.of(context).pop(_buildProfile());
  }

  void _previewCard() {
    Navigator.of(context).pop(_buildProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _PhotoPicker(
                  photoPath: _photoPath,
                  isLoading: _isPickingImage,
                  onTap: _pickPhoto,
                ),
              ),
              const SizedBox(height: 32),
              GlassCard(
                padding: const EdgeInsets.all(20),
                radius: AppTheme.radiusMedium,
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taglineController,
                      decoration: const InputDecoration(
                        labelText: 'Tag (optional)',
                        prefixIcon: Icon(Icons.short_text_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // "Your Links" heading with + icon
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Text(
                      'Your Links',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _addLink,
                      tooltip: 'Add Link',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (_links.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 12),
              if (_links.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No links yet. Add Instagram, WhatsApp, or your Website —\neach becomes its own QR you can swipe between.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ..._links.map(
                  (link) => Padding(
                    key: ValueKey(link.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LinkRow(
                      link: link,
                      isDefault: link.id == _defaultLinkId,
                      onRemove: () => _removeLink(link.id),
                      onSetDefault: () => _handleSetDefault(link.id),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _save,
                child: const SizedBox(
                  width: double.infinity,
                  child: Text('Save', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _previewCard,
                child: const SizedBox(
                  width: double.infinity,
                  child: Text('Preview Card', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 28),
              const Center(child: VersionFooter()),
            ],
          ),
        ),
      ),
    );
  }
}

/// One saved link in the editable list.
///
/// Deletion now shows a confirmation dialog.
class _LinkRow extends StatefulWidget {
  final LinkEntry link;
  final bool isDefault;
  final VoidCallback onRemove;
  final VoidCallback onSetDefault;

  const _LinkRow({
    Key? key,
    required this.link,
    required this.isDefault,
    required this.onRemove,
    required this.onSetDefault,
  }) : super(key: key);

  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  static const _holdDuration = Duration(seconds: 3);
  Timer? _holdTimer;
  bool _isHolding = false;

  void _startHold() {
    _holdTimer?.cancel();
    setState(() => _isHolding = true);
    _holdTimer = Timer(_holdDuration, () {
      if (!mounted) return;
      setState(() => _isHolding = false);
      widget.onSetDefault();
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_isHolding) setState(() => _isHolding = false);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  /// Shows a confirmation dialog, then calls onRemove if confirmed.
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Delete link?'),
        content: Text('Are you sure you want to remove "${widget.link.displayLabel}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (widget.link.platform) {
      LinkPlatform.instagram => Icons.camera_alt_outlined,
      LinkPlatform.whatsapp => Icons.chat_bubble_outline_rounded,
      LinkPlatform.website => Icons.language_rounded,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: widget.isDefault
            ? Border.all(color: Colors.white, width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        radius: AppTheme.radiusSmall,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: widget.onSetDefault,
                onTapDown: (_) => _startHold(),
                onTapUp: (_) => _cancelHold(),
                onTapCancel: _cancelHold,
                child: AnimatedScale(
                  scale: _isHolding ? 0.97 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.link.displayLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.isDefault) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.bolt_rounded, size: 15, color: Colors.white),
                                ],
                              ],
                            ),
                            Text(
                              widget.link.displayValue,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Trash/dustbin icon with confirmation
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.white.withOpacity(0.6),
              onPressed: _confirmDelete,
              tooltip: 'Delete link',
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for adding a new link.
class _AddLinkSheet extends StatefulWidget {
  final String id;
  const _AddLinkSheet({required this.id});
  @override
  State<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<_AddLinkSheet> {
  // svayatta.in is the only website this card offers — hardcoded rather
  // than a free-text field, since there's nothing for the user to type.
  static const _websiteValue = 'svayatta.in';

  LinkPlatform _platform = LinkPlatform.instagram;
  final _valueController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _selectPlatform(LinkPlatform platform) {
    setState(() {
      _platform = platform;
      if (platform == LinkPlatform.website) {
        _valueController.text = _websiteValue;
      } else if (_valueController.text == _websiteValue) {
        // Switching away from Website — don't leave its auto-filled
        // value sitting in the Instagram/WhatsApp field.
        _valueController.clear();
      }
    });
  }

  void _submit() {
    final value = _platform == LinkPlatform.website
        ? _websiteValue
        : _valueController.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(
      LinkEntry(
        id: widget.id,
        platform: _platform,
        value: value,
        label: _labelController.text.trim().isEmpty
            ? null
            : _labelController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a Link', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PlatformChip(
                  label: 'Instagram',
                  icon: Icons.camera_alt_outlined,
                  selected: _platform == LinkPlatform.instagram,
                  onTap: () => _selectPlatform(LinkPlatform.instagram),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlatformChip(
                  label: 'WhatsApp',
                  icon: Icons.chat_bubble_outline_rounded,
                  selected: _platform == LinkPlatform.whatsapp,
                  onTap: () => _selectPlatform(LinkPlatform.whatsapp),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlatformChip(
                  label: 'Website',
                  icon: Icons.language_rounded,
                  selected: _platform == LinkPlatform.website,
                  onTap: () => _selectPlatform(LinkPlatform.website),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_platform == LinkPlatform.website)
            // Nothing to type — this platform only ever points at
            // svayatta.in, so show that plainly instead of an empty field.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    color: Colors.white.withOpacity(0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'svayatta.in',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Fixed',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            TextField(
              controller: _valueController,
              autofocus: true,
              keyboardType: _platform == LinkPlatform.whatsapp
                  ? TextInputType.phone
                  : TextInputType.url,
              decoration: InputDecoration(
                labelText: _platform == LinkPlatform.instagram
                    ? 'Instagram username or URL'
                    : 'WhatsApp phone number',
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label (optional, e.g. "Personal")',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: const SizedBox(
              width: double.infinity,
              child: Text('Add', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PlatformChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.black : Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final String? photoPath;
  final bool isLoading;
  final VoidCallback onTap;
  const _PhotoPicker({
    required this.photoPath,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && File(photoPath!).existsSync();
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedScale(
        scale: isLoading ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white24),
                image: hasPhoto
                    ? DecorationImage(
                        image: FileImage(File(photoPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : (!hasPhoto
                      ? Icon(Icons.person_rounded,
                          size: 48, color: Colors.white.withOpacity(0.5))
                      : null),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                size: 16,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}