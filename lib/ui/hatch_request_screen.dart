import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../application/app_controller.dart';
import '../data/pet_pack_service.dart';
import 'theme/pet_colors.dart';
import 'theme/pixel_background.dart';
import 'theme/pet_spacing.dart';
import 'theme/pet_text_styles.dart';
import 'theme/stair_border.dart';
import 'widgets/pixel_components.dart';
import 'widgets/pixel_icon.dart';

const String invalidPackMessage =
    "This pack doesn't fit — ask for a fresh one.";

Future<bool> importPetPackFromPicker(
  BuildContext context,
  AppController controller,
) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const <String>['pettodopet', 'zip'],
  );
  final path = result?.files.single.path;
  if (path == null) return false;
  try {
    await controller.importPetPack(File(path));
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    return true;
  } on PetPackException {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(invalidPackMessage)));
    }
    return false;
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(invalidPackMessage)));
    }
    return false;
  }
}

Future<void> shareHatchRequest(
  BuildContext context,
  AppController controller, {
  Rect? origin,
}) async {
  final file = await controller.exportHatchRequest();
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'application/zip')],
      title: 'Send to the adoption center',
      subject: 'PetTodo adoption request',
      sharePositionOrigin: origin,
    ),
  );
}

class HatchRequestScreen extends StatefulWidget {
  const HatchRequestScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HatchRequestScreen> createState() => _HatchRequestScreenState();
}

class _HatchRequestScreenState extends State<HatchRequestScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _name = TextEditingController();
  final List<XFile> _photos = <XFile>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickGallery() async {
    final remaining = 5 - _photos.length;
    if (remaining <= 0) return;
    final chosen = await _picker.pickMultiImage(limit: remaining);
    if (!mounted) return;
    setState(() => _photos.addAll(chosen.take(remaining)));
  }

  Future<void> _takePhoto() async {
    if (_photos.length == 5) return;
    final photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null && mounted) setState(() => _photos.add(photo));
  }

  Future<void> _save() async {
    if (_saving || _photos.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.controller.createHatchRequest(
        photos: _photos
            .map((photo) => File(photo.path))
            .toList(growable: false),
        petName: _name.text,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PixelBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            PetSpacing.s20,
            PetSpacing.s14,
            PetSpacing.s20,
            PetSpacing.s24,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const PxIcon(PxIconData.back),
                ),
                const SizedBox(width: PetSpacing.s8),
                const Expanded(
                  child: Text(
                    'Adopt your own pet',
                    style: PetTextStyles.display24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PetSpacing.s20),
            if (widget.controller.pendingHatchRequest == null)
              _NewRequest(
                photos: _photos,
                name: _name,
                saving: _saving,
                onGallery: _pickGallery,
                onCamera: _takePhoto,
                onRemove: (index) => setState(() => _photos.removeAt(index)),
                onSave: _save,
              )
            else
              _PendingRequest(controller: widget.controller),
          ],
        ),
      ),
    ),
  );
}

class _NewRequest extends StatelessWidget {
  const _NewRequest({
    required this.photos,
    required this.name,
    required this.saving,
    required this.onGallery,
    required this.onCamera,
    required this.onRemove,
    required this.onSave,
  });

  final List<XFile> photos;
  final TextEditingController name;
  final bool saving;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final ValueChanged<int> onRemove;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => _HatchPanel(
    children: <Widget>[
      const Center(
        child: ExcludeSemantics(
          child: PxIcon(
            PxIconData.paw,
            size: PetSpacing.s78,
            color: PetColors.inactive,
          ),
        ),
      ),
      const Text(
        'Choose 1–5 clear photos. Nothing leaves this device until you choose to share it.',
        style: PetTextStyles.body15Soft,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: PetSpacing.s18),
      if (photos.isNotEmpty)
        Wrap(
          spacing: PetSpacing.s8,
          runSpacing: PetSpacing.s8,
          children: List<Widget>.generate(
            photos.length,
            (index) => Semantics(
              container: true,
              label: 'Pet photo ${index + 1}',
              child: Stack(
                children: <Widget>[
                  ClipPath(
                    clipper: const ShapeBorderClipper(
                      shape: StairBorder.large(),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Image.file(
                      File(photos[index].path),
                      width: PetSpacing.s78,
                      height: PetSpacing.s78,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      tooltip: 'Remove photo ${index + 1}',
                      onPressed: () => onRemove(index),
                      icon: const PxIcon(PxIconData.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: PetSpacing.s14),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: photos.length < 5 ? onGallery : null,
              icon: const PxIcon(PxIconData.photo, size: 18),
              label: const Text('Photo library'),
            ),
          ),
          const SizedBox(width: PetSpacing.s10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: photos.length < 5 ? onCamera : null,
              icon: const PxIcon(PxIconData.camera, size: 18),
              label: const Text('Camera'),
            ),
          ),
        ],
      ),
      const SizedBox(height: PetSpacing.s18),
      TextField(
        controller: name,
        maxLength: 20,
        decoration: const InputDecoration(
          labelText: 'Pet name (optional)',
          counterText: '',
        ),
      ),
      const SizedBox(height: PetSpacing.s18),
      FilledButton(
        onPressed: photos.isNotEmpty && !saving ? onSave : null,
        child: Text(saving ? 'Saving gently…' : 'Start the adoption'),
      ),
    ],
  );
}

class _PendingRequest extends StatelessWidget {
  const _PendingRequest({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => _HatchPanel(
    children: <Widget>[
      const Center(
        child: ExcludeSemantics(
          child: PxIcon(
            PxIconData.paw,
            size: PetSpacing.s78,
            color: PetColors.inactive,
          ),
        ),
      ),
      const Text(
        'Your pet is on its way — no rush.',
        style: PetTextStyles.display24,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: PetSpacing.s8),
      const Text(
        'Send the request when it feels right, then import the pet pack you receive.',
        style: PetTextStyles.body15Soft,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: PetSpacing.s18),
      Builder(
        builder: (buttonContext) => FilledButton.icon(
          onPressed: () async {
            final box = buttonContext.findRenderObject()! as RenderBox;
            await shareHatchRequest(
              buttonContext,
              controller,
              origin: box.localToGlobal(Offset.zero) & box.size,
            );
          },
          icon: const PxIcon(
            PxIconData.share,
            size: 18,
            color: PetColors.white,
          ),
          label: const Text('Send to the adoption center'),
        ),
      ),
      const SizedBox(height: PetSpacing.s10),
      OutlinedButton.icon(
        onPressed: () => importPetPackFromPicker(context, controller),
        icon: const PxIcon(PxIconData.package, size: 18),
        label: const Text('Import pet pack'),
      ),
      const SizedBox(height: PetSpacing.s10),
      TextButton(
        onPressed: () async {
          await controller.cancelHatchRequest();
          if (context.mounted) Navigator.of(context).pop();
        },
        child: const Text('Cancel this request'),
      ),
    ],
  );
}

class _HatchPanel extends StatelessWidget {
  const _HatchPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PxCard(
    padding: const EdgeInsets.all(PetSpacing.s20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}
