import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// A clean form for editing the local profile, including an open-ended
/// list of links (Instagram, WhatsApp, etc.) — each becomes one
/// swipeable QR card on the Share screen.
///
/// Returns the updated [Profile] via Navigator.pop when the user saves,
/// or null if they back out without saving. Does not write to storage
/// itself — ShareScreen's onProfileChanged callback (wired in main.dart)
/// owns persistence, keeping this screen focused on form state only.
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
  bool _isPickingImage = false;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _taglineController = TextEditingController(text: widget.profile.tagline);
    _links = List.of(widget.profile.links);
    _photoPath = widget.profile.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  Profile _buildProfile() {
    return Profile(
      fullName: _nameController.text.trim(),
      tagline: _taglineController.text.trim(),
      photoPath: _photoPath,
      links: _links,
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

      // Copy into app's own documents directory so the file persists
      // even if the user removes it from the gallery/source location.
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

  Future<void> _addLink() async {
    final newLink = await showModalBottomSheet<LinkEntry>(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.92),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _AddLinkSheet(id: 'link_${_nextId++}'),
    );
    if (newLink != null) {
      setState(() => _links.add(newLink));
    }
  }

  void _removeLink(String id) {
    setState(() => _links.removeWhere((l) => l.id == id));
  }

  void _save() {
    Navigator.of(context).pop(_buildProfile());
  }

  void _previewCard() {
    // "Preview Card" returns to the Share Screen with current edits applied,
    // same as Save — there's no separate preview-only state to enter.
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
                        labelText: 'Tagline (optional)',
                        prefixIcon: Icon(Icons.short_text_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Your Links',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              if (_links.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No links yet. Add Instagram, WhatsApp, or more —\neach becomes its own QR you can swipe between.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ..._links.map(
                  (link) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LinkRow(
                      link: link,
                      onRemove: () => _removeLink(link.id),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addLink,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Link'),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// One saved link in the editable list — shows its platform icon, value,
/// and a remove button. Pure black-and-white, no platform brand colors.
class _LinkRow extends StatelessWidget {
  final LinkEntry link;
  final VoidCallback onRemove;

  const _LinkRow({required this.link, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final icon = link.platform == LinkPlatform.instagram
        ? Icons.camera_alt_outlined
        : Icons.chat_bubble_outline_rounded;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: AppTheme.radiusSmall,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.displayLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  link.displayValue,
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: Colors.white.withOpacity(0.6),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for adding a new link: pick platform, enter value,
/// optionally label it (so two Instagrams can be told apart).
class _AddLinkSheet extends StatefulWidget {
  final String id;

  const _AddLinkSheet({required this.id});

  @override
  State<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<_AddLinkSheet> {
  LinkPlatform _platform = LinkPlatform.instagram;
  final _valueController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _valueController.text.trim();
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
                  onTap: () =>
                      setState(() => _platform = LinkPlatform.instagram),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlatformChip(
                  label: 'WhatsApp',
                  icon: Icons.chat_bubble_outline_rounded,
                  selected: _platform == LinkPlatform.whatsapp,
                  onTap: () =>
                      setState(() => _platform = LinkPlatform.whatsapp),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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