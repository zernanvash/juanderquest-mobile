import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';
import '../utils/spot_posting.dart';

class SpotPostingSheetResult {
  final SpotPostingDraft draft;
  final int resumeStep;
  final bool movePinRequested;
  final SpotModel? publishedSpot;

  const SpotPostingSheetResult({
    required this.draft,
    required this.resumeStep,
    this.movePinRequested = false,
    this.publishedSpot,
  });
}

class SpotPostingSheet extends ConsumerStatefulWidget {
  final double initialLat;
  final double initialLng;
  final SpotPostingDraft? initialDraft;
  final int initialStep;

  const SpotPostingSheet({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialDraft,
    this.initialStep = 0,
  });

  @override
  ConsumerState<SpotPostingSheet> createState() => _SpotPostingSheetState();
}

class _SpotPostingSheetState extends ConsumerState<SpotPostingSheet> {
  late SpotPostingDraft _draft;
  late int _stepIndex;
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
  bool _mediaUploading = false;
  String? _mediaAssetId;
  String? _mediaUrl;
  String? _mediaError;

  String get _stepId => spotPostingSteps[_stepIndex];

  @override
  void initState() {
    super.initState();
    final base = widget.initialDraft ?? const SpotPostingDraft();
    _draft = base.copyWith(lat: widget.initialLat, lng: widget.initialLng);
    _stepIndex = widget.initialDraft == null ? 0 : widget.initialStep.clamp(0, spotPostingSteps.length - 1);
    _nameController.text = _draft.name;
    _descriptionController.text = _draft.description;
    _municipalityController.text = _draft.municipality;
    _addressController.text = _draft.address;
    _hoursController.text = _draft.dailyHours;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _municipalityController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  void _syncTextFields() {
    _draft = _draft.copyWith(
      name: _nameController.text,
      description: _descriptionController.text,
      municipality: _municipalityController.text,
      address: _addressController.text,
      dailyHours: _hoursController.text,
    );
  }

  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    setState(() {
      final next = Map<String, String>.from(_fieldErrors);
      next.remove(field);
      _fieldErrors = next;
    });
  }

  void _handleNext() {
    _syncTextFields();
    final errors = validatePostingStep(_stepId, _draft);
    if (errors.isNotEmpty) {
      setState(() => _fieldErrors = errors);
      return;
    }
    setState(() {
      _fieldErrors = {};
      _stepIndex = (_stepIndex + 1).clamp(0, spotPostingSteps.length - 1);
    });
  }

  void _handleBack() {
    _syncTextFields();
    setState(() {
      _fieldErrors = {};
      _stepIndex = (_stepIndex - 1).clamp(0, spotPostingSteps.length - 1);
    });
  }

  void _requestMovePin() {
    _syncTextFields();
    Navigator.of(context).pop(
      SpotPostingSheetResult(
        draft: _draft,
        resumeStep: spotPostingSteps.indexOf('place'),
        movePinRequested: true,
      ),
    );
  }

  Future<void> _pickMedia(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      final length = await picked.length();
      final sizeError = validatePostingMediaSize(length, isVideo: false);
      if (sizeError != null) {
        setState(() => _mediaError = sizeError);
        return;
      }
      setState(() {
        _mediaFile = picked;
        _mediaAssetId = null;
        _mediaUrl = null;
        _mediaError = null;
      });
      await _uploadMedia();
    } catch (e) {
      setState(() => _mediaError = 'Failed to select photo: $e');
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
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'media': MultipartFile.fromBytes(bytes, filename: file.name),
      });
      final response = await client.dio.post('/spot-media', data: formData);
      if (response.statusCode == 201 && response.data['success'] == true) {
        setState(() {
          _mediaAssetId = response.data['data']['asset_id'] as String?;
          _mediaUrl = response.data['data']['url'] as String?;
        });
      } else {
        setState(() => _mediaError = response.data['error']?['message'] ?? 'Upload failed.');
      }
    } on DioException catch (e) {
      setState(() => _mediaError = e.response?.data?['error']?['message'] ?? 'Network error uploading photo.');
    } catch (e) {
      setState(() => _mediaError = 'Unexpected upload error: $e');
    } finally {
      if (mounted) setState(() => _mediaUploading = false);
    }
  }

  Future<void> _publish() async {
    if (_submitting || _publishedSpot != null) return;
    _syncTextFields();
    final errors = validatePostingStep('review', _draft);
    if (errors.isNotEmpty) {
      setState(() => _fieldErrors = errors);
      final firstInvalid = firstInvalidPostingStep(_draft);
      if (firstInvalid != null) {
        final targetIndex = spotPostingSteps.indexOf(firstInvalid);
        if (targetIndex >= 0) setState(() => _stepIndex = targetIndex);
      }
      return;
    }
    if (_mediaUploading) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.post(
        '/spots',
        data: buildSpotPayload(_draft, assetId: _mediaAssetId, imageUrl: _mediaUrl),
      );
      if (response.statusCode == 201 && response.data['success'] == true) {
        final spot = SpotModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
        setState(() => _publishedSpot = spot);
      } else {
        setState(() => _submitError = response.data['error']?['message'] ?? 'Failed to add spot.');
      }
    } on DioException catch (e) {
      setState(() => _submitError = e.response?.data?['error']?['message'] ?? 'Failed to connect to server.');
    } catch (e) {
      setState(() => _submitError = 'Submission failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _finishPublished() {
    final spot = _publishedSpot;
    if (spot == null) return;
    Navigator.of(context).pop(
      SpotPostingSheetResult(
        draft: _draft,
        resumeStep: _stepIndex,
        publishedSpot: spot,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: _publishedSpot != null ? _buildSuccessView() : _buildWizardView(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final spot = _publishedSpot!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: AppSpacing.roundedXl,
            ),
            child: const Icon(Icons.celebration_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'Destination published',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.woodBrown,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${spot.name} is now visible on the map and community feed.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(
                      SpotPostingSheetResult(
                        draft: _draft,
                        resumeStep: _stepIndex,
                        publishedSpot: spot,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Back to map'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _finishPublished,
            child: const Text('View destination on map', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildWizardView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: AppSpacing.roundedLg,
                ),
                child: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pin a destination',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.woodBrown),
                    ),
                    Text(
                      'Step ${_stepIndex + 1} of ${spotPostingSteps.length} · ${spotPostingStepLabels[_stepId]}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (_stepIndex + 1) / spotPostingSteps.length,
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceContainerLow,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                tooltip: 'Close posting wizard',
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildStepBody(),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: OutlinedButton.icon(
                    onPressed: _stepIndex == 0 || _submitting ? null : _handleBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back'),
                  ),
                ),
              ),
              const Spacer(),
              if (_stepId == 'review')
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: FilledButton.icon(
                      onPressed: _submitting || _mediaUploading ? null : _publish,
                      icon: _submitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(_submitting ? 'Publishing…' : 'Publish destination'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sunGold,
                        foregroundColor: AppColors.woodBrown,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: FilledButton.icon(
                      onPressed: _handleNext,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Next'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepBody() {
    switch (_stepId) {
      case 'basics':
        return _buildBasicsStep();
      case 'story':
        return _buildStoryStep();
      case 'place':
        return _buildPlaceStep();
      case 'details':
        return _buildDetailsStep();
      case 'media':
        return _buildMediaStep();
      default:
        return _buildReviewStep();
    }
  }

  Widget _buildFieldError(String field) {
    final message = _fieldErrors[field];
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: const OutlineInputBorder(borderRadius: AppSpacing.roundedLg),
    );
  }

  Widget _buildBasicsStep() {
    final subcategories = subcategoriesForCategory(_draft.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          maxLength: 200,
          onChanged: (_) => _clearFieldError('name'),
          decoration: _inputDecoration('Destination name *', hint: 'e.g. Tambobong White Beach'),
        ),
        _buildFieldError('name'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _draft.category,
          isExpanded: true,
          decoration: _inputDecoration('Category *'),
          items: spotPostingCategories
              .map((category) => DropdownMenuItem<String>(
                    value: category['id'] as String,
                    child: Text(
                      category['label'] as String,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            final options = subcategoriesForCategory(value);
            setState(() {
              _draft = _draft.copyWith(
                category: value,
                subcategory: options.isEmpty ? _draft.subcategory : options.first,
              );
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: subcategories.contains(_draft.subcategory) ? _draft.subcategory : null,
          isExpanded: true,
          decoration: _inputDecoration('Subcategory *'),
          items: subcategories
              .map((subcategory) => DropdownMenuItem<String>(
                    value: subcategory,
                    child: Text(
                      subcategory.replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _draft = _draft.copyWith(subcategory: value));
          },
        ),
        _buildFieldError('subcategory'),
      ],
    );
  }

  Widget _buildStoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _descriptionController,
          autofocus: true,
          maxLines: 5,
          maxLength: 2000,
          onChanged: (_) => _clearFieldError('description'),
          decoration: _inputDecoration(
            'What makes it worth visiting? *',
            hint: 'Describe the place, what travelers can do, and any honest tips.',
          ),
        ),
        _buildFieldError('description'),
      ],
    );
  }

  Widget _buildPlaceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: AppSpacing.roundedLg,
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatPinLabel(_draft.lat, _draft.lng),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TextButton(
                    onPressed: _requestMovePin,
                    child: const Text('Move pin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildFieldError('pin'),
        const SizedBox(height: 12),
        TextField(
          controller: _municipalityController,
          maxLength: 100,
          onChanged: (_) => _clearFieldError('municipality'),
          decoration: _inputDecoration('Municipality / city *', hint: 'e.g. Dasol'),
        ),
        _buildFieldError('municipality'),
        const SizedBox(height: 4),
        TextField(
          controller: _addressController,
          maxLength: 300,
          onChanged: (_) => _clearFieldError('address'),
          decoration: _inputDecoration('Address / landmark *', hint: 'e.g. Brgy. Tambobong, Dasol'),
        ),
        _buildFieldError('address'),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _hoursController,
          maxLength: 80,
          decoration: _inputDecoration('Operating hours (optional)', hint: 'e.g. 06:00 AM - 06:00 PM'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Price level',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(spotPostingPriceLabels.length, (level) {
            final selected = _draft.priceLevel == level;
            return ChoiceChip(
              label: Text(spotPostingPriceLabels[level], style: const TextStyle(fontSize: 11)),
              selected: selected,
              onSelected: (_) => setState(() => _draft = _draft.copyWith(priceLevel: level)),
            );
          }),
        ),
        const SizedBox(height: 12),
        const Text(
          'Amenities (optional)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: spotPostingAmenities.map((amenity) {
            final selected = _draft.amenities.contains(amenity);
            return FilterChip(
              label: Text(amenity.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  final next = List<String>.from(_draft.amenities);
                  if (value) {
                    next.add(amenity);
                  } else {
                    next.remove(amenity);
                  }
                  _draft = _draft.copyWith(amenities: next);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMediaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A real photo helps travelers trust this destination. You can publish without one.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        if (_mediaFile == null)
          OutlinedButton.icon(
            onPressed: () => _pickMedia(ImageSource.gallery),
            icon: const Icon(Icons.upload_rounded, size: 16),
            label: const Text('Choose a photo'),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppSpacing.roundedLg,
                child: Image.file(
                  File(_mediaFile!.path),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    color: AppColors.surfaceContainerLow,
                    child: const Text('Photo selected', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_mediaUploading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_mediaAssetId != null)
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success)
                  else
                    const Icon(Icons.error_rounded, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    _mediaUploading ? 'Uploading…' : (_mediaAssetId != null ? 'Uploaded' : 'Upload failed'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (!_mediaUploading && _mediaAssetId == null)
                    TextButton(onPressed: _uploadMedia, child: const Text('Retry', style: TextStyle(fontSize: 11))),
                  TextButton(
                    onPressed: () => setState(() {
                      _mediaFile = null;
                      _mediaAssetId = null;
                      _mediaUrl = null;
                      _mediaError = null;
                    }),
                    child: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        if (_mediaError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _mediaError!,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppSpacing.roundedLg,
            border: Border.all(color: AppColors.borderLowContrast),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _draft.name.trim().isEmpty ? 'Untitled destination' : _draft.name.trim(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.woodBrown),
              ),
              const SizedBox(height: 4),
              Text(
                _draft.description.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '${_draft.category} · ${_draft.subcategory.replaceAll('_', ' ')}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              Text(
                '${_draft.municipality} — ${_draft.address}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              Text(
                formatPinLabel(_draft.lat, _draft.lng),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                _mediaAssetId != null ? 'Photo attached' : (_mediaFile != null ? 'Photo pending upload' : 'No photo (optional)'),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _requestMovePin,
          icon: const Icon(Icons.place_rounded, size: 14),
          label: const Text('Adjust pin on map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        const Text(
          'Posting publishes this destination immediately. Future reports or moderation can update it.',
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        if (_submitError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Text(
                _submitError!,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          ),
      ],
    );
  }
}
