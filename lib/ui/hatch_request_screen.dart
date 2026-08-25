import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../application/app_controller.dart';
import '../application/hatch_flow.dart';
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
      subject: 'Pawside adoption request',
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
  final TextEditingController _speciesWish = TextEditingController();
  final List<XFile> _photos = <XFile>[];
  bool _saving = false;
  bool _unlocking = false;
  bool _leavingForCeremony = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    if (!_leavingForCeremony &&
        widget.controller.hatchFlow.phase == HatchFlowPhase.ready) {
      _leavingForCeremony = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _name.dispose();
    _speciesWish.dispose();
    super.dispose();
  }

  Future<void> _pickGallery() async {
    final remaining = 3 - _photos.length;
    if (remaining <= 0) return;
    final chosen = await _picker.pickMultiImage(limit: remaining);
    if (!mounted) return;
    setState(() => _photos.addAll(chosen.take(remaining)));
  }

  Future<void> _takePhoto() async {
    if (_photos.length == 3) return;
    final photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null && mounted) setState(() => _photos.add(photo));
  }

  Future<void> _save() async {
    if (_saving || _photos.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.controller.startHatch(
        photos: _photos
            .map((photo) => File(photo.path))
            .toList(growable: false),
        petName: _name.text,
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Those photos could not be saved just now. They are still in your library.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unlock() async {
    if (_unlocking) return;
    setState(() => _unlocking = true);
    try {
      await widget.controller.unlockHatching();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The unlock could not be saved just now. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
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
            // the unlock card always leads while locked — a legacy concierge
            // request stays reachable below it instead of hiding the gate
            if (!widget.controller.hatchUnlocked) ...<Widget>[
              _UnlockCard(
                priceLabel: widget.controller.hatchPriceLabel,
                unlocking: _unlocking,
                onUnlock: _unlock,
              ),
              const SizedBox(height: PetSpacing.s14),
              if (widget.controller.pendingHatchRequest != null)
                // _PendingRequest carries its own import affordance; a second
                // button here would duplicate the semantics node
                _PendingRequest(
                  controller: widget.controller,
                  speciesWish: _speciesWish,
                )
              else
                OutlinedButton.icon(
                  onPressed: () =>
                      importPetPackFromPicker(context, widget.controller),
                  icon: const PxIcon(PxIconData.package, size: 18),
                  label: const Text('Import pet pack'),
                ),
            ] else if (widget.controller.pendingHatchRequest != null)
              _PendingRequest(
                controller: widget.controller,
                speciesWish: _speciesWish,
              )
            else
              _NewRequest(
                photos: _photos,
                name: _name,
                saving: _saving,
                onGallery: _pickGallery,
                onCamera: _takePhoto,
                onRemove: (index) => setState(() => _photos.removeAt(index)),
                onSave: _save,
              ),
          ],
        ),
      ),
    ),
  );
}

class _UnlockCard extends StatelessWidget {
  const _UnlockCard({
    required this.priceLabel,
    required this.unlocking,
    required this.onUnlock,
  });

  final String priceLabel;
  final bool unlocking;
  final VoidCallback onUnlock;

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
        'Bring your own pet home',
        style: PetTextStyles.display24,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: PetSpacing.s8),
      const Text(
        'One unlock includes 3 hatches for your own cat or dog.',
        style: PetTextStyles.body15Soft,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: PetSpacing.s8),
      Text(
        priceLabel,
        style: PetTextStyles.captionSoft,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: PetSpacing.s18),
      FilledButton(
        onPressed: unlocking ? null : onUnlock,
        child: Text(unlocking ? 'Unlocking…' : 'Unlock'),
      ),
    ],
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
        'Adding photos from different angles can improve the result.',
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
              onPressed: photos.length < 3 ? onGallery : null,
              icon: const PxIcon(PxIconData.photo, size: 18),
              label: const Text('Photo library'),
            ),
          ),
          const SizedBox(width: PetSpacing.s10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: photos.length < 3 ? onCamera : null,
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
        child: Text(saving ? 'Settling the egg…' : 'Start the adoption'),
      ),
    ],
  );
}

class _PendingRequest extends StatelessWidget {
  const _PendingRequest({required this.controller, required this.speciesWish});

  final AppController controller;
  final TextEditingController speciesWish;

  @override
  Widget build(BuildContext context) {
    final flow = controller.hatchFlow;
    final waiting =
        flow.phase == HatchFlowPhase.submitting ||
        flow.phase == HatchFlowPhase.incubating ||
        flow.phase == HatchFlowPhase.downloading;
    final canRetry =
        flow.phase == HatchFlowPhase.connectionIssue ||
        flow.phase == HatchFlowPhase.failed;
    // a persisted request that predates the online flow (or survived a
    // restart) has no active run yet — offer to start it
    final canStart =
        flow.phase == HatchFlowPhase.idle && controller.hatchUnlocked;
    return _HatchPanel(
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
        Text(
          _statusMessage(flow),
          style: PetTextStyles.body15Soft,
          textAlign: TextAlign.center,
        ),
        if (waiting) ...<Widget>[
          const SizedBox(height: PetSpacing.s14),
          Center(
            child: Semantics(
              label: 'Hatching in progress',
              child: const SizedBox.square(
                dimension: PetSpacing.s24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
        ],
        if (canRetry || canStart) ...<Widget>[
          const SizedBox(height: PetSpacing.s18),
          FilledButton(
            onPressed: controller.retryHatch,
            child: Text(canStart ? 'Start hatching' : 'Try again'),
          ),
        ],
        if (flow.phase == HatchFlowPhase.speciesUnsupported) ...<Widget>[
          const SizedBox(height: PetSpacing.s18),
          if (flow.wishSent)
            const Text(
              'Wish saved. Thank you for helping the nursery grow.',
              style: PetTextStyles.body15Soft,
              textAlign: TextAlign.center,
            )
          else ...<Widget>[
            TextField(
              controller: speciesWish,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'A species you hope to welcome (optional)',
                counterText: '',
              ),
            ),
            const SizedBox(height: PetSpacing.s10),
            OutlinedButton(
              onPressed: () {
                final wish = speciesWish.text.trim().isNotEmpty
                    ? speciesWish.text.trim()
                    : flow.detectedSpecies ?? '';
                if (wish.isNotEmpty) controller.submitSpeciesWish(wish);
              },
              child: const Text('Send species wish'),
            ),
          ],
        ],
        const SizedBox(height: PetSpacing.s18),
        const Text(
          'Offline options',
          style: PetTextStyles.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PetSpacing.s8),
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

  static String _statusMessage(HatchFlowState flow) {
    if (flow.message != null) return flow.message!;
    switch (flow.phase) {
      case HatchFlowPhase.idle:
        return 'Your photos are saved here. You can start the online hatch again or use the offline options.';
      case HatchFlowPhase.locked:
        return 'Unlock hatching whenever it feels right.';
      case HatchFlowPhase.submitting:
        return 'The nursery is receiving your photos.';
      case HatchFlowPhase.incubating:
        return 'The egg is warm and hatching now.';
      case HatchFlowPhase.downloading:
        return 'Your pet is ready and finding its way home.';
      case HatchFlowPhase.ready:
        return 'Your pet is home.';
      case HatchFlowPhase.failed:
      case HatchFlowPhase.quotaExhausted:
      case HatchFlowPhase.speciesUnsupported:
      case HatchFlowPhase.connectionIssue:
        return 'Your saved request is still here.';
    }
  }
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
