import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';
import '../providers/spot_recognition_provider.dart';
import '../studio/pixel/studio_category_grid.dart';
import '../studio/pixel/studio_icons.dart';
import '../studio/pixel/studio_section.dart';
import '../studio/pixel/studio_text.dart';
import '../studio/pixel/studio_text_field.dart';
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
  bool _categoryPicked = false;
  bool _detailsOpen = false;
  bool _showAllStarters = false;
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
    _categoryPicked = widget.initialDraft != null ||
        (rec != null &&
            spotPostingCategories.any(
              (category) => category['id'] == rec.suggestedCategory,
            ));
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
      _categoryPicked = _categoryPicked ||
          spotPostingCategories.any(
            (category) => category['id'] == rec.suggestedCategory,
          );
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

  void _selectCategory(String id) {
    _readTextFields();
    _touched = _touched.copyWith(category: true);
    _categoryPicked = true;
    _update(_draft.copyWith(
      category: id,
      subcategory: subcategoriesForCategory(id).first,
    ));
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
          'Publishing failed. Your answers are kept; try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full-screen studio: keep the Publish bar above the Android navigation bar (edge-to-edge).
    if (widget.embedded) return SafeArea(top: false, child: _buildComposer());
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.92),
          child: Material(
            color: PixelPalette.paper,
            clipBehavior: Clip.antiAlias,
            child:
                _publishedSpot != null ? _buildSuccessView() : _buildComposer(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final grid = PixelGrid.of(context);
    final spot = _publishedSpot!;
    void done() => Navigator.of(context)
        .pop(SpotPostingSheetResult(draft: _draft, publishedSpot: spot));
    return SingleChildScrollView(
      padding: EdgeInsets.all(grid.px(4)),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Destination published',
              textAlign: TextAlign.center,
              style: PixelType.title(context),
            ),
            SizedBox(height: grid.px(1)),
            Text(
              '${spot.name} is now visible on the map. Plan a trail through it or get directions.',
              textAlign: TextAlign.center,
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(3)),
            PixelButton(
              label: 'Show it on the map',
              icon: StudioIcons.pin,
              iconScale: 2,
              expand: true,
              onPressed: done,
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(String key) {
    final message = _fieldErrors[key];
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: PixelGrid.of(context).px(0.5)),
      child: Text(
        message,
        style: PixelType.small(context, color: PixelPalette.redDeep),
      ),
    );
  }

  Widget _buildComposer() {
    final grid = PixelGrid.of(context);
    final readiness = studioReadinessHint(_currentDraft);
    return Column(
      mainAxisSize: widget.embedded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (!widget.embedded) _buildSheetHeader(context, grid),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              widget.embedded ? 0 : grid.px(4),
              widget.embedded ? 0 : grid.px(2),
              widget.embedded ? 0 : grid.px(4),
              widget.embedded ? 0 : grid.px(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header != null) widget.header!,
                if (widget.embedded) SizedBox(height: grid.px(3)),
                _buildPlaceSection(context, grid),
                SizedBox(height: grid.px(2)),
                _buildPhotosSection(context, grid),
                SizedBox(height: grid.px(2)),
                _buildNameSection(context, grid),
                SizedBox(height: grid.px(2)),
                _buildCategorySection(context, grid),
                SizedBox(height: grid.px(2)),
                _buildStorySection(context, grid),
                SizedBox(height: grid.px(2)),
                _buildDetailsSection(context, grid),
                if (widget.footerBuilder != null) ...[
                  SizedBox(height: grid.px(3)),
                  Text(
                    'Preview',
                    style: PixelType.body(context)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: grid.px(1)),
                  widget.footerBuilder!(
                      _currentDraft, _mediaFile, _mediaIsVideo),
                ],
                if (_submitError != null) ...[
                  SizedBox(height: grid.px(2)),
                  PixelPanel(
                    style: PixelBoxStyle.red,
                    padding: 2,
                    child: Text(
                      _submitError!,
                      style: PixelType.small(
                        context,
                        color: PixelPalette.white,
                      ),
                    ),
                  ),
                ],
                if (widget.embedded) SizedBox(height: grid.px(2)),
              ],
            ),
          ),
        ),
        _buildPublishBar(context, grid, readiness),
      ],
    );
  }

  Widget _buildSheetHeader(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Add this place',
              style: PixelType.title(context),
            ),
          ),
          SizedBox(width: grid.px(1)),
          PixelIconButton(
            icon: StudioIcons.close,
            semanticLabel: 'Close',
            iconHeight: 18,
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceSection(BuildContext context, PixelGrid grid) {
    final place = _recognizing
        ? 'Recognizing this place'
        : formatRecognizedPlaceLabel(_draft);
    return StudioSection(
      step: 1,
      title: 'Place',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelPanel(
            style: PixelBoxStyle.slot,
            padding: 1,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.body(
                          context,
                          color: PixelPalette.greenDark,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (_draft.address.isNotEmpty)
                        Text(
                          _draft.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: grid.px(1)),
                PixelChip(
                  _editAddress ? 'Close' : 'Edit',
                  key: const ValueKey('studio_edit_address'),
                  style: PixelBoxStyle.slot,
                  textColor: PixelPalette.greenDark,
                  onTap: () => setState(() => _editAddress = !_editAddress),
                ),
              ],
            ),
          ),
          if (_recognition?.outsidePangasinan == true) ...[
            SizedBox(height: grid.px(1)),
            PixelPanel(
              style: PixelBoxStyle.gold,
              padding: 1,
              child: Text(
                'This pin is outside Pangasinan. Double-check the location.',
                style: PixelType.small(
                  context,
                  color: PixelPalette.goldDeep,
                ),
              ),
            ),
          ],
          if (_editAddress) ...[
            SizedBox(height: grid.px(2)),
            StudioTextField(
              key: const ValueKey('studio_municipality'),
              controller: _municipalityController,
              label: 'Municipality / city',
              maxLength: 100,
              errorText: _fieldErrors['municipality'],
              onChanged: (_) =>
                  setState(() => _touched = _touched.copyWith(location: true)),
            ),
            SizedBox(height: grid.px(2)),
            StudioTextField(
              key: const ValueKey('studio_address'),
              controller: _addressController,
              label: 'Address / landmark',
              maxLength: 300,
              errorText: _fieldErrors['address'],
              minLines: 2,
              maxLines: 3,
              onChanged: (_) =>
                  setState(() => _touched = _touched.copyWith(location: true)),
            ),
          ],
          if (!widget.embedded) ...[
            SizedBox(height: grid.px(2)),
            PixelButton(
              label: 'Adjust pin',
              icon: StudioIcons.pin,
              iconScale: 2,
              variant: PixelButtonVariant.secondary,
              onPressed: _requestMovePin,
            ),
          ],
          _error('pin'),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(BuildContext context, PixelGrid grid) {
    final hasMedia = _mediaFile != null || _mediaUrl != null;
    return StudioSection(
      step: 2,
      title: 'Photos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: PixelButton(
                  key: const ValueKey('studio_media_camera'),
                  label: 'Camera',
                  icon: StudioIcons.camera,
                  iconScale: 2,
                  expand: true,
                  onPressed: () => _pickMedia(source: ImageSource.camera),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: PixelButton(
                  key: const ValueKey('studio_media_gallery'),
                  label: 'Gallery',
                  icon: StudioIcons.gallery,
                  iconScale: 2,
                  expand: true,
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => _pickMedia(source: ImageSource.gallery),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: PixelButton(
                  key: const ValueKey('studio_media_video'),
                  label: 'Video 30s',
                  icon: StudioIcons.video,
                  iconScale: 2,
                  expand: true,
                  variant: PixelButtonVariant.secondary,
                  onPressed: () =>
                      _pickMedia(source: ImageSource.gallery, video: true),
                ),
              ),
            ],
          ),
          if (hasMedia) ...[
            SizedBox(height: grid.px(1)),
            _mediaPreview(context, grid),
          ],
          if (_mediaError != null && !hasMedia) ...[
            SizedBox(height: grid.px(1)),
            Text(
              _mediaError!,
              style: PixelType.small(context, color: PixelPalette.redDeep),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mediaPreview(BuildContext context, PixelGrid grid) {
    final thumbnail = _mediaIsVideo
        ? null
        : _mediaFile != null
            ? Image.file(
                File(_mediaFile!.path),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const Center(
                  child: PixelSprite(StudioIcons.gallery, scale: 2),
                ),
              )
            : _mediaUrl != null
                ? Image.network(
                    _mediaUrl!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => const Center(
                      child: PixelSprite(StudioIcons.gallery, scale: 2),
                    ),
                  )
                : null;
    final status = _mediaUploading
        ? 'Uploading'
        : _mediaAssetId != null
            ? 'Uploaded'
            : _mediaError ?? 'Upload failed';
    return PixelPanel(
      style: PixelBoxStyle.slot,
      padding: 1,
      child: Row(
        children: [
          SizedBox(
            width: grid.px(16),
            height: grid.px(16),
            child: thumbnail ??
                Center(
                  child: PixelSprite(
                    _mediaIsVideo ? StudioIcons.video : StudioIcons.camera,
                    scale: 2,
                  ),
                ),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mediaIsVideo ? 'Video cover' : 'Photo cover',
                  style: PixelType.body(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  status,
                  style: PixelType.small(
                    context,
                    color: _mediaAssetId != null || _mediaUploading
                        ? PixelPalette.greenDark
                        : PixelPalette.redDeep,
                  ),
                ),
              ],
            ),
          ),
          if (!_mediaUploading && _mediaAssetId == null)
            PixelChip(
              'Retry',
              style: PixelBoxStyle.slot,
              textColor: PixelPalette.greenDark,
              onTap: _uploadMedia,
            ),
          SizedBox(width: grid.px(1)),
          PixelIconButton(
            icon: StudioIcons.close,
            semanticLabel: 'Remove media',
            iconHeight: 16,
            onPressed: _removeMedia,
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection(BuildContext context, PixelGrid grid) {
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
    return StudioSection(
      step: 3,
      title: 'Name',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioTextField(
            key: const ValueKey('studio_name'),
            controller: _nameController,
            label: 'Destination name',
            hint: 'e.g. Tambobong White Beach',
            maxLength: 200,
            errorText: _fieldErrors['name'],
            onChanged: (_) =>
                setState(() => _touched = _touched.copyWith(name: true)),
          ),
          if (suggestions.isNotEmpty) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Suggestions',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(0.5)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final name in suggestions)
                  PixelChip(
                    name,
                    key: ValueKey('studio_name_suggestion_$name'),
                    style: PixelBoxStyle.slot,
                    textColor: PixelPalette.greenDark,
                    onTap: () => setState(() {
                      _nameController.text = name;
                      _touched = _touched.copyWith(name: true);
                    }),
                  ),
              ],
            ),
          ],
          if (autoFilled) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Auto-recognized from map',
              style: PixelType.small(context, color: PixelPalette.greenDark),
            ),
          ],
          if (duplicate != null) ...[
            SizedBox(height: grid.px(1)),
            PixelPanel(
              style: PixelBoxStyle.gold,
              padding: 1,
              child: Text(
                'Looks close to ${duplicate.name} (${duplicate.distanceMeters} m away). Continue only if it is a different place.',
                style: PixelType.small(
                  context,
                  color: PixelPalette.goldDeep,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, PixelGrid grid) {
    return StudioSection(
      step: 4,
      title: 'Category',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioCategoryGrid(
            selectedCategory: _draft.category,
            picked: _categoryPicked,
            onSelected: _selectCategory,
          ),
          if (_categoryPicked) ...[
            SizedBox(height: grid.px(2)),
            Text(
              'Type',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(0.5)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final sub in subcategoriesForCategory(_draft.category))
                  PixelChip(
                    studioSubcategoryName(sub),
                    key: ValueKey('studio_subtype_$sub'),
                    style: _draft.subcategory == sub
                        ? PixelBoxStyle.green
                        : PixelBoxStyle.slot,
                    textColor: _draft.subcategory == sub
                        ? PixelPalette.white
                        : PixelPalette.slate,
                    onTap: () {
                      _readTextFields();
                      _touched = _touched.copyWith(category: true);
                      _update(_draft.copyWith(subcategory: sub));
                    },
                  ),
              ],
            ),
          ],
          _error('category'),
          _error('subcategory'),
        ],
      ),
    );
  }

  Widget _buildStorySection(BuildContext context, PixelGrid grid) {
    final starters = _recognition?.storyStarters ?? const <String>[];
    final visible = _showAllStarters ? starters : starters.take(3).toList();
    final length = _descriptionController.text.trim().length;
    return StudioSection(
      step: 5,
      title: 'Story',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioTextField(
            key: const ValueKey('studio_description'),
            controller: _descriptionController,
            label: 'Description',
            hint:
                'Describe the place, what travelers can do, and any honest tips.',
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            errorText: _fieldErrors['description'],
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: grid.px(0.5)),
          Text(
            length >= 20 ? 'Description looks good' : 'At least 20 characters.',
            style: PixelType.small(
              context,
              color: length >= 20 ? PixelPalette.greenDark : PixelPalette.slate,
            ),
          ),
          if (starters.isNotEmpty) ...[
            SizedBox(height: grid.px(2)),
            Text(
              'Suggestions',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(0.5)),
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) SizedBox(height: grid.px(1)),
              _StoryStarterRow(
                starter: visible[i],
                used: _usedStarters.contains(visible[i]),
                onTap: () => setState(() {
                  _descriptionController.text = appendStoryStarter(
                      _descriptionController.text, visible[i]);
                  _usedStarters.add(visible[i]);
                  _fieldErrors = {};
                }),
              ),
            ],
            if (starters.length > 3) ...[
              SizedBox(height: grid.px(1)),
              PixelChip(
                _showAllStarters ? 'Fewer ideas' : 'More ideas',
                key: const ValueKey('studio_more_ideas'),
                style: PixelBoxStyle.slot,
                textColor: PixelPalette.greenDark,
                onTap: () =>
                    setState(() => _showAllStarters = !_showAllStarters),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, PixelGrid grid) {
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

    return StudioSection(
      step: 6,
      title: 'Visitor details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label:
                _detailsOpen ? 'Hide visitor details' : 'Show visitor details',
            child: ExcludeSemantics(
              child: GestureDetector(
                key: const ValueKey('studio_details_toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _detailsOpen = !_detailsOpen),
                child: PixelPanel(
                  style: PixelBoxStyle.slot,
                  padding: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Who · When · Hours',
                              style: PixelType.small(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                            if (summary.isNotEmpty)
                              Text(
                                summary,
                                key: const ValueKey('studio_details_summary'),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: PixelType.small(context),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: grid.px(1)),
                      PixelChip(
                        _detailsOpen ? 'Hide' : 'Open',
                        style: PixelBoxStyle.slot,
                        textColor: PixelPalette.greenDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_detailsOpen) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Good for (max 5)',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(0.5)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final entry in spotGoodForOptions.entries)
                  _toggleChip(
                    context,
                    label: entry.value,
                    selected: _draft.goodFor.contains(entry.key),
                    onTap: () {
                      final list = [..._draft.goodFor];
                      if (list.contains(entry.key)) {
                        list.remove(entry.key);
                      } else if (list.length < 5) {
                        list.add(entry.key);
                      }
                      touchDetails(_draft.copyWith(goodFor: list));
                    },
                  ),
              ],
            ),
            _error('goodFor'),
            SizedBox(height: grid.px(1)),
            Text(
              'Best time (max 4)',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(0.5)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final entry in spotBestTimeOptions.entries)
                  _toggleChip(
                    context,
                    label: entry.value,
                    selected: _draft.bestTime.contains(entry.key),
                    onTap: () {
                      final list = [..._draft.bestTime];
                      if (list.contains(entry.key)) {
                        list.remove(entry.key);
                      } else if (list.length < 4) {
                        list.add(entry.key);
                      }
                      touchDetails(_draft.copyWith(bestTime: list));
                    },
                  ),
              ],
            ),
            _error('bestTime'),
            SizedBox(height: grid.px(2)),
            StudioTextField(
              key: const ValueKey('studio_hours'),
              controller: _hoursController,
              label: 'Operating hours',
              hint: 'e.g. 06:00 AM - 06:00 PM',
              maxLength: 80,
              errorText: _fieldErrors['dailyHours'],
              onChanged: (value) {
                _touched = _touched.copyWith(details: true);
                _draft = _draft.copyWith(dailyHours: value);
              },
            ),
            SizedBox(height: grid.px(1)),
            Text(
              'Amenities',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(0.5)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              children: [
                for (final amenity in spotPostingAmenities)
                  _toggleChip(
                    context,
                    label: studioSubcategoryName(amenity),
                    selected: _draft.amenities.contains(amenity),
                    onTap: () {
                      final list = [..._draft.amenities];
                      if (list.contains(amenity)) {
                        list.remove(amenity);
                      } else {
                        list.add(amenity);
                      }
                      touchDetails(_draft.copyWith(amenities: list));
                    },
                  ),
              ],
            ),
            _error('amenities'),
          ],
        ],
      ),
    );
  }

  Widget _toggleChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return PixelChip(
      label,
      style: selected ? PixelBoxStyle.green : PixelBoxStyle.slot,
      textColor: selected ? PixelPalette.white : PixelPalette.slate,
      onTap: onTap,
    );
  }

  Widget _buildPublishBar(
    BuildContext context,
    PixelGrid grid,
    String? readiness,
  ) {
    final label = _mediaUploading ? 'Finishing your upload' : readiness;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        grid.px(3),
        grid.px(2),
        grid.px(3),
        grid.px(2),
      ),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label ?? 'Ready to publish',
              style: PixelType.small(
                context,
                color: label == null
                    ? PixelPalette.greenDark
                    : PixelPalette.goldDeep,
              ),
            ),
            SizedBox(height: grid.px(1)),
            PixelButton(
              key: const ValueKey('studio_publish'),
              label: _submitting ? 'Publishing' : 'Publish spot',
              icon: StudioIcons.edit,
              iconScale: 2,
              expand: true,
              loading: _submitting,
              onPressed: _submitting || _mediaUploading ? null : _publish,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryStarterRow extends StatelessWidget {
  const _StoryStarterRow({
    required this.starter,
    required this.used,
    required this.onTap,
  });

  final String starter;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !used,
      label: used ? 'Added: $starter' : 'Add: $starter',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('studio_starter_${starter.hashCode}'),
          behavior: HitTestBehavior.opaque,
          onTap: used ? null : onTap,
          child: PixelPanel(
            style: used ? PixelBoxStyle.green : PixelBoxStyle.parchment,
            padding: 1,
            child: Text(
              used ? 'Added · $starter' : '+ $starter',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(
                context,
                color: used ? PixelPalette.white : PixelPalette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
