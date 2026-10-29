import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';
import '../providers/spot_recognition_provider.dart';
import '../utils/spot_posting.dart';

class SpotPostingSheetResult {
  final SpotPostingDraft draft;
  final bool movePinRequested;
  final SpotModel? publishedSpot;

  const SpotPostingSheetResult({
    required this.draft,
    this.movePinRequested = false,
    this.publishedSpot,
  });
}

/// Plan 66 stage 2: one pre-filled "Smart Draft" page (replaces the 6-step wizard).
class SpotPostingSheet extends ConsumerStatefulWidget {
  final double initialLat;
  final double initialLng;
  final SpotPostingDraft? initialDraft;

  /// Recognition already fetched by the map's aim card for this pin (skips a second lookup).
  final SpotRecognitionResult? initialRecognition;

  /// Plan 70: embedded in the Spot Discovery Studio page instead of a bottom sheet. The pin
  /// (initialLat/initialLng) may then change at any time; the composer re-recognizes it.
  final bool embedded;
  final Widget? header;
  final Widget Function(
      SpotPostingDraft draft, XFile? media, bool mediaIsVideo)? footerBuilder;
  final ValueChanged<SpotModel>? onPublished;
  final ValueChanged<SpotPostingDraft>? onDraftChanged;
  final ValueChanged<XFile>? onPhotoPicked;

  const SpotPostingSheet({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialDraft,
    this.initialRecognition,
    this.embedded = false,
    this.header,
    this.footerBuilder,
    this.onPublished,
    this.onDraftChanged,
    this.onPhotoPicked,
  });

  @override
  ConsumerState<SpotPostingSheet> createState() => _SpotPostingSheetState();
}

class _SpotPostingSheetState extends ConsumerState<SpotPostingSheet> {
  late SpotPostingDraft _draft;
  SpotRecognitionResult? _recognition;
  bool _recognizing = false;
  SpotPostingTouched _touched = const SpotPostingTouched();
  final Set<String> _usedStarters = {};
  bool _editAddress = false;
  Map<String, String> _fieldErrors = {};
  bool _submitting = false;
  String? _submitError;
  SpotModel? _publishedSpot;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _addressController = TextEditingController();
  final _hoursController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _mediaFile;
  bool _mediaIsVideo = false;
  bool _mediaUploading = false;
  String? _mediaAssetId;
  String? _mediaUrl;
  String? _mediaError;

  @override
  void initState() {
    super.initState();
    final base = (widget.initialDraft ?? const SpotPostingDraft())
        .copyWith(lat: widget.initialLat, lng: widget.initialLng);
    // A resumed draft (after Adjust pin) keeps everything the traveler already chose.
    if (widget.initialDraft != null) {
      _touched =
          const SpotPostingTouched(name: true, category: true, details: true);
    }
    final rec = widget.initialRecognition;
    _draft =
        rec == null ? base : applyRecognition(base, rec, touched: _touched);
    _recognition = rec;
    _syncControllers();
    for (final controller in [
      _nameController,
      _descriptionController,
      _municipalityController,
      _addressController,
      _hoursController
    ]) {
      controller.addListener(_emitDraft);
    }
    if (rec == null) _recognize();
  }

  @override
  void didUpdateWidget(covariant SpotPostingSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLat != widget.initialLat ||
        oldWidget.initialLng != widget.initialLng) {
      _readTextFields();
      _draft = _draft.copyWith(lat: widget.initialLat, lng: widget.initialLng);
      _recognize();
    }
  }

  SpotPostingDraft get _currentDraft => _draft.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
        municipality: _municipalityController.text,
        address: _addressController.text,
        dailyHours: _hoursController.text,
      );

  void _emitDraft() => widget.onDraftChanged?.call(_currentDraft);

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _municipalityController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _nameController.text = _draft.name;
    _descriptionController.text = _draft.description;
    _municipalityController.text = _draft.municipality;
    _addressController.text = _draft.address;
    _hoursController.text = _draft.dailyHours;
  }

  int _recognizeRun = 0;

  Future<void> _recognize() async {
    final run = ++_recognizeRun;
    final lat = _draft.lat ?? widget.initialLat,
        lng = _draft.lng ?? widget.initialLng;
    setState(() => _recognizing = true);
    final rec = await ref
        .read(spotRecognitionApiProvider)
        .recognizeLocation(lat: lat, lng: lng);
    // A newer pin was requested meanwhile; its own lookup wins.
    if (!mounted || run != _recognizeRun) return;
    _readTextFields();
    setState(() {
      _recognizing = false;
      _recognition = rec;
      _draft = applyRecognition(_draft, rec, touched: _touched);
      _syncControllers();
    });
    _emitDraft();
  }

  void _readTextFields() {
    _draft = _draft.copyWith(
      name: _nameController.text,
      description: _descriptionController.text,
      municipality: _municipalityController.text,
      address: _addressController.text,
      dailyHours: _hoursController.text,
    );
  }

  void _update(SpotPostingDraft next) {
    setState(() {
      _draft = next;
      _fieldErrors = {};
    });
    _emitDraft();
  }

  void _requestMovePin() {
    _readTextFields();
    Navigator.of(context)
        .pop(SpotPostingSheetResult(draft: _draft, movePinRequested: true));
  }

  Future<void> _pickMedia(
      {required ImageSource source, bool video = false}) async {
    try {
      final picked = video
          ? await _picker.pickVideo(
              source: source, maxDuration: const Duration(seconds: 30))
          : await _picker.pickImage(
              source: source,
              maxWidth: 1920,
              maxHeight: 1920,
              imageQuality: 85);
      if (picked == null) return;
      final sizeError =
          validatePostingMediaSize(await picked.length(), isVideo: video);
      if (sizeError != null) {
        setState(() => _mediaError = sizeError);
        return;
      }
      if (!video) widget.onPhotoPicked?.call(picked);
      setState(() {
        _mediaFile = picked;
        _mediaIsVideo = video;
        _mediaAssetId = null;
        _mediaUrl = null;
        _mediaError = null;
      });
      await _uploadMedia(); // starts right away so publishing never waits on the upload
    } catch (_) {
      setState(() => _mediaError =
          video ? 'Could not open the video.' : 'Could not open the photo.');
    }
  }

  Future<void> _uploadMedia() async {
    final file = _mediaFile;
    if (file == null) return;
    setState(() {
      _mediaUploading = true;
      _mediaError = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'media': MultipartFile.fromBytes(await file.readAsBytes(),
            filename: file.name)
      });
      final response = await client.dio.post('/spot-media', data: formData);
      if (response.statusCode == 201 && response.data['success'] == true) {
        setState(() {
          _mediaAssetId = response.data['data']['asset_id'] as String?;
          _mediaUrl = response.data['data']['url'] as String?;
        });
      } else {
        setState(() => _mediaError =
            response.data['error']?['message'] ?? 'Upload failed.');
      }
    } on DioException catch (e) {
      setState(() => _mediaError = e.response?.data?['error']?['message'] ??
          'Network error uploading media.');
    } catch (_) {
      setState(() => _mediaError = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _mediaUploading = false);
    }
  }

  void _removeMedia() {
    setState(() {
      _mediaFile = null;
      _mediaAssetId = null;
      _mediaUrl = null;
      _mediaError = null;
    });
  }

  Future<void> _publish() async {
    if (_submitting || _publishedSpot != null || _mediaUploading) return;
    _readTextFields();
    final errors = validatePostingDraft(_draft);
    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors = errors;
        if (errors.containsKey('municipality') ||
            errors.containsKey('address')) {
          _editAddress = true;
        }
      });
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.post('/spots',
          data: buildSpotPayload(_draft,
              assetId: _mediaAssetId, imageUrl: _mediaUrl));
      if (response.statusCode == 201 && response.data['success'] == true) {
        final spot = SpotModel.fromJson(
            Map<String, dynamic>.from(response.data['data'] as Map));
        setState(() => _publishedSpot = spot);
        widget.onPublished?.call(spot);
      } else {
        setState(() => _submitError =
            response.data['error']?['message'] ?? 'Failed to add spot.');
      }
    } on DioException catch (e) {
      setState(() => _submitError = e.response?.data?['error']?['message'] ??
          'Failed to connect to server.');
    } catch (_) {
      setState(() => _submitError =
          'Publishing failed. Your answers are kept — try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildComposer();
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.92),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child:
                _publishedSpot != null ? _buildSuccessView() : _buildComposer(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final spot = _publishedSpot!;
    void done() => Navigator.of(context)
        .pop(SpotPostingSheetResult(draft: _draft, publishedSpot: spot));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: AppSpacing.roundedXl),
            child: const Icon(Icons.celebration_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'Destination published',
            style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w900, color: AppColors.woodBrown),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${spot.name} is now visible on the map. Plan a trail through it or get directions.',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: done,
              icon: const Icon(Icons.place_rounded, size: 16),
              label: const Text('Show it on the map'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.woodBrown)),
              ),
              if (trailing != null) Flexible(child: trailing),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _error(String key) {
    final message = _fieldErrors[key];
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(message,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red)),
    );
  }

  Widget _buildComposer() {
    final readiness = postingReadiness(_draft.copyWith(
      name: _nameController.text,
      description: _descriptionController.text,
      municipality: _municipalityController.text,
      address: _addressController.text,
    ));
    return Column(
      mainAxisSize: widget.embedded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (!widget.embedded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Add this place',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.woodBrown)),
                ),
                IconButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(widget.embedded ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header != null) widget.header!,
                if (widget.embedded) const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: widget.embedded ? 16 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLocationCard(),
                      const SizedBox(height: 16),
                      _buildMediaBar(),
                      const SizedBox(height: 16),
                      _buildName(),
                      _buildCategory(),
                      _buildStory(),
                      _buildDetails(),
                      if (_submitError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_submitError!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red)),
                        ),
                      if (widget.footerBuilder != null) ...[
                        const SizedBox(height: 16),
                        widget.footerBuilder!(
                            _currentDraft, _mediaFile, _mediaIsVideo),
                      ],
                      if (widget.embedded) const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _mediaUploading
                      ? 'Finishing your upload…'
                      : readiness ?? '✓ Ready to publish',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: readiness == null
                        ? AppColors.primary
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: FilledButton.icon(
                    onPressed: _submitting || _mediaUploading ? null : _publish,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sunGold,
                        foregroundColor: AppColors.woodBrown),
                    icon: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(_submitting ? 'Publishing…' : 'Publish spot'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    final place = _recognizing
        ? 'Recognizing this place…'
        : formatRecognizedPlaceLabel(_draft);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.place_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary)),
                    if (_draft.address.isNotEmpty)
                      Text(_draft.address,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (_recognition?.outsidePangasinan == true)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'This pin is outside Pangasinan. Double-check the location.',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E))),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              // In the studio the map sits right above; drag it instead.
              if (!widget.embedded)
                OutlinedButton.icon(
                  onPressed: _requestMovePin,
                  icon: const Icon(Icons.open_with_rounded, size: 14),
                  label: const Text('Adjust pin'),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _editAddress = !_editAddress),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: Text(_editAddress
                    ? 'Hide address fields'
                    : 'Edit address manually'),
              ),
            ],
          ),
          if (_editAddress) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _municipalityController,
              maxLength: 100,
              decoration: const InputDecoration(
                  labelText: 'Municipality / city', counterText: ''),
              onChanged: (_) =>
                  setState(() => _touched = _touched.copyWith(location: true)),
            ),
            _error('municipality'),
            TextField(
              controller: _addressController,
              maxLength: 300,
              decoration: const InputDecoration(
                  labelText: 'Address / landmark', counterText: ''),
              onChanged: (_) =>
                  setState(() => _touched = _touched.copyWith(location: true)),
            ),
            _error('address'),
          ],
          _error('pin'),
        ],
      ),
    );
  }

  Widget _buildMediaBar() {
    final file = _mediaFile;
    if (file != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderLowContrast),
            borderRadius: AppSpacing.roundedLg),
        child: Row(
          children: [
            Icon(_mediaIsVideo ? Icons.movie_rounded : Icons.photo_rounded,
                color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _mediaUploading
                    ? 'Uploading…'
                    : _mediaAssetId != null
                        ? '✓ Uploaded · cover ${_mediaIsVideo ? 'video' : 'photo'}'
                        : _mediaError ?? 'Upload failed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _mediaAssetId != null || _mediaUploading
                      ? AppColors.primary
                      : Colors.red,
                ),
              ),
            ),
            if (!_mediaUploading && _mediaAssetId == null)
              TextButton(onPressed: _uploadMedia, child: const Text('Retry')),
            IconButton(
                onPressed: _removeMedia,
                tooltip: 'Remove media',
                icon: const Icon(Icons.delete_outline_rounded, size: 18)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _pickMedia(source: ImageSource.camera),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.photo_camera_rounded, size: 16),
              label: const Text('Take photo'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickMedia(source: ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded, size: 16),
              label: const Text('Gallery'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _pickMedia(source: ImageSource.gallery, video: true),
              icon: const Icon(Icons.videocam_rounded, size: 16),
              label: const Text('30s video'),
            ),
          ],
        ),
        if (_mediaError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_mediaError!,
                style: const TextStyle(fontSize: 11, color: Colors.red)),
          ),
      ],
    );
  }

  Widget _buildName() {
    final rec = _recognition;
    final autoFilled = rec?.placeName != null &&
        !_touched.name &&
        _nameController.text == rec!.placeName;
    final suggestions = (rec?.nameSuggestions ?? const <String>[])
        .where((n) => n != _nameController.text)
        .take(3)
        .toList();
    final duplicate = rec?.nearbyDuplicates.isNotEmpty == true
        ? rec!.nearbyDuplicates.first
        : null;
    return _section(
      'Destination name *',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'e.g. Tambobong White Beach',
              counterText: '',
              suffixIcon: _nameController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear name',
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => setState(() {
                        _nameController.clear();
                        _touched = _touched.copyWith(name: true);
                      }),
                    ),
            ),
            onChanged: (_) =>
                setState(() => _touched = _touched.copyWith(name: true)),
          ),
          if (suggestions.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                for (final name in suggestions)
                  ActionChip(
                    label: Text(name),
                    onPressed: () => setState(() {
                      _nameController.text = name;
                      _touched = _touched.copyWith(name: true);
                    }),
                  ),
              ],
            ),
          if (duplicate != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Looks close to ${duplicate.name} (${duplicate.distanceMeters} m away). Continue only if it is a different place.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
              ),
            ),
          _error('name'),
        ],
      ),
      trailing: autoFilled
          ? const Text('✨ Auto-recognized from map',
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary))
          : null,
    );
  }

  Widget _buildCategory() {
    return _section(
      'Category',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final category in spotPostingCategories)
                ChoiceChip(
                  label: Text(category['label'] as String),
                  selected: _draft.category == category['id'],
                  onSelected: (_) {
                    _readTextFields();
                    _touched = _touched.copyWith(category: true);
                    final id = category['id'] as String;
                    _update(_draft.copyWith(
                        category: id,
                        subcategory: subcategoriesForCategory(id).first));
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final sub in subcategoriesForCategory(_draft.category))
                ChoiceChip(
                  label: Text(sub.replaceAll('_', ' ')),
                  selected: _draft.subcategory == sub,
                  onSelected: (_) {
                    _readTextFields();
                    _touched = _touched.copyWith(category: true);
                    _update(_draft.copyWith(subcategory: sub));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStory() {
    final starters = _recognition?.storyStarters ?? const <String>[];
    final length = _descriptionController.text.trim().length;
    return _section(
      'What makes it worth visiting? *',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (starters.isNotEmpty) ...[
            const Text('✨ Tap to build your description:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const SizedBox(height: 4),
            for (final starter in starters)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    backgroundColor: _usedStarters.contains(starter)
                        ? AppColors.primary.withOpacity(0.08)
                        : null,
                  ),
                  onPressed: _usedStarters.contains(starter)
                      ? null
                      : () => setState(() {
                            _descriptionController.text = appendStoryStarter(
                                _descriptionController.text, starter);
                            _usedStarters.add(starter);
                            _fieldErrors = {};
                          }),
                  child: Text(
                      '${_usedStarters.contains(starter) ? '✓' : '+'} $starter',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
          ],
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText:
                  'Describe the place, what travelers can do, and any honest tips.',
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text(
            length >= 20
                ? '✓ Description looks good'
                : 'At least 20 characters.',
            style: TextStyle(
                fontSize: 11,
                color: length >= 20 ? AppColors.primary : AppColors.textMuted),
          ),
          _error('description'),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final summary = [
      _draft.goodFor.map((id) => spotGoodForOptions[id] ?? id).join(' & '),
      _draft.bestTime.map((id) => spotBestTimeOptions[id] ?? id).join('/'),
      _draft.dailyHours,
    ].where((part) => part.isNotEmpty).join(' · ');
    void touchDetails(SpotPostingDraft next) {
      _readTextFields();
      _touched = _touched.copyWith(details: true);
      _update(next);
    }

    return Material(
      color: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: AppSpacing.roundedLg,
        side: BorderSide(color: AppColors.borderLowContrast),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text('✨ Visitor details',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.woodBrown)),
          subtitle: summary.isEmpty
              ? null
              : Text(summary,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Good for (max 5)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 6,
              children: [
                for (final entry in spotGoodForOptions.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _draft.goodFor.contains(entry.key),
                    onSelected: (on) {
                      final list = [..._draft.goodFor];
                      if (!on) {
                        list.remove(entry.key);
                      } else if (list.length < 5) {
                        list.add(entry.key);
                      }
                      touchDetails(_draft.copyWith(goodFor: list));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Best time (max 4)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 6,
              children: [
                for (final entry in spotBestTimeOptions.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _draft.bestTime.contains(entry.key),
                    onSelected: (on) {
                      final list = [..._draft.bestTime];
                      if (!on) {
                        list.remove(entry.key);
                      } else if (list.length < 4) {
                        list.add(entry.key);
                      }
                      touchDetails(_draft.copyWith(bestTime: list));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hoursController,
              maxLength: 80,
              decoration: const InputDecoration(
                  labelText: 'Operating hours',
                  hintText: 'e.g. 06:00 AM - 06:00 PM',
                  counterText: ''),
              onChanged: (value) {
                _touched = _touched.copyWith(details: true);
                _draft = _draft.copyWith(dailyHours: value);
              },
            ),
            const SizedBox(height: 8),
            const Text('Amenities',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 6,
              children: [
                for (final amenity in spotPostingAmenities)
                  FilterChip(
                    label: Text(amenity.replaceAll('_', ' ')),
                    selected: _draft.amenities.contains(amenity),
                    onSelected: (on) {
                      final list = [..._draft.amenities];
                      if (on) {
                        list.add(amenity);
                      } else {
                        list.remove(amenity);
                      }
                      touchDetails(_draft.copyWith(amenities: list));
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
