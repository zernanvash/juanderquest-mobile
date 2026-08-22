import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';

class AddSpotScreen extends ConsumerStatefulWidget {
  const AddSpotScreen({super.key});

  @override
  ConsumerState<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends ConsumerState<AddSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _muniController = TextEditingController(text: 'Lingayen');
  final _addressController = TextEditingController();
  final _latController = TextEditingController(text: '16.0218');
  final _lngController = TextEditingController(text: '120.2319');

  String _category = 'nature_outdoors';
  String _subcategory = 'park';
  final _picker = ImagePicker();

  XFile? _selectedFile;
  bool _uploading = false;
  double _uploadProgress = 0.0;
  String? _uploadedAssetId;
  String? _uploadedUrl;
  String? _uploadError;

  bool _submitting = false;
  String? _submitError;

  final Map<String, List<String>> _subcategoriesMap = {
    'eat_drink': ['restaurant', 'carinderia', 'cafe', 'bakery', 'street_food', 'bar'],
    'nature_outdoors': ['beach', 'waterfall', 'cave', 'park', 'trailhead', 'viewpoint'],
    'culture_heritage': ['church', 'museum', 'heritage_site', 'arts_crafts'],
    'activities_wellness': ['sports_venue', 'running_spot', 'gym', 'recreation', 'water_activity'],
    'shopping_local': ['market', 'souvenir', 'local_products'],
    'stay': ['hotel', 'resort', 'homestay', 'campsite'],
  };

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _muniController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _uploadError = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (picked == null) return;

      final length = await picked.length();
      if (length > 8 * 1024 * 1024) {
        setState(() {
          _uploadError = 'File size exceeds 8 MB limit.';
        });
        return;
      }

      setState(() {
        _selectedFile = picked;
        _uploadedAssetId = null;
        _uploadedUrl = null;
      });
    } catch (e) {
      setState(() {
        _uploadError = 'Failed to select photo: $e';
      });
    }
  }

  Future<void> _uploadPhoto() async {
    if (_selectedFile == null) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final fileName = _selectedFile!.name;
      final fileBytes = await _selectedFile!.readAsBytes();

      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });

      final response = await client.dio.post(
        '/spot-photos',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        final data = response.data['data'];
        setState(() {
          _uploadedAssetId = data['asset_id'];
          _uploadedUrl = data['url'];
        });
      } else {
        setState(() {
          _uploadError = response.data['error']?['message'] ?? 'Upload failed.';
        });
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? 'Network error uploading photo.';
      setState(() {
        _uploadError = msg;
      });
    } catch (e) {
      setState(() {
        _uploadError = 'Unexpected upload error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _submitSpot() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final client = ref.read(apiClientProvider);

      if (_selectedFile != null && _uploadedAssetId == null) {
        await _uploadPhoto();
        if (_uploadedAssetId == null) {
          setState(() {
            _submitting = false;
            _submitError = _uploadError ?? 'Photo upload failed.';
          });
          return;
        }
      }

      final payload = {
        'name': _nameController.text.trim(),
        'category': _category,
        'subcategory': _subcategory,
        'description': _descController.text.trim(),
        'municipality': _muniController.text.trim(),
        'address': _addressController.text.trim(),
        'gps_lat': double.tryParse(_latController.text) ?? 16.0218,
        'gps_lng': double.tryParse(_lngController.text) ?? 120.2319,
        'price_level': 0,
        'hours': {'daily': '08:00-18:00'},
        'tags': ['community', 'scenic'],
        'amenities': ['parking'],
        'image_url': _uploadedUrl ?? '',
        if (_uploadedAssetId != null) 'asset_id': _uploadedAssetId,
        if (_uploadedAssetId != null) 'asset_ids': [_uploadedAssetId!],
      };

      final response = await client.dio.post('/spots', data: payload);

      if (response.statusCode == 201 && response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Destination spot submitted for community review!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
        }
      } else {
        setState(() {
          _submitError = response.data['error']?['message'] ?? 'Failed to add spot.';
        });
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? 'Failed to connect to server.';
      setState(() {
        _submitError = msg;
      });
    } catch (e) {
      setState(() {
        _submitError = 'Submission failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subcategories = _subcategoriesMap[_category] ?? ['park'];

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(
        title: const Text('Contribute a Spot'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),

            // Review Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.crowdQuietBg,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.rate_review_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Community Spot Contribution',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.woodBrown,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Submissions enter community & LGU review before being published on JuanderQuest.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Photo Upload Section
            JdqSectionHeader(
              title: '1. Destination Photo',
              subtitle: 'Attach a clear photo of the destination (Max 8 MB).',
            ),

            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(color: AppColors.borderLowContrast),
              ),
              child: Column(
                children: [
                  if (_selectedFile != null)
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(color: AppColors.borderLowContrast),
                      ),
                      child: ClipRRect(
                        borderRadius: AppSpacing.roundedMd,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_selectedFile!.path),
                              fit: BoxFit.cover,
                            ),
                            if (_uploadedAssetId != null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    borderRadius: AppSpacing.roundedPill,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Uploaded',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(color: AppColors.borderLowContrast, style: BorderStyle.solid),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.primary),
                          SizedBox(height: 8),
                          Text('No photo selected yet', style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  if (_uploading) ...[
                    LinearProgressIndicator(value: _uploadProgress, color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(
                      'Uploading photo... ${(_uploadProgress * 100).toInt()}%',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (_uploadError != null) ...[
                    Text(
                      _uploadError!,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Camera',
                          icon: Icons.camera_alt_rounded,
                          onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Gallery',
                          icon: Icons.photo_library_rounded,
                          onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sectionGap),

            // Spot Identity & Category Section
            JdqSectionHeader(
              title: '2. Spot Details',
              subtitle: 'Provide the name, category, and description of the spot.',
            ),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Spot Name',
                hintText: 'e.g. Cape Bolinao Lighthouse',
              ),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a spot name.' : null,
            ),

            const SizedBox(height: AppSpacing.md),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'nature_outdoors', child: Text('Nature & Outdoors')),
                DropdownMenuItem(value: 'eat_drink', child: Text('Food & Drinks')),
                DropdownMenuItem(value: 'culture_heritage', child: Text('Culture & Heritage')),
                DropdownMenuItem(value: 'activities_wellness', child: Text('Activities & Wellness')),
                DropdownMenuItem(value: 'shopping_local', child: Text('Local Shopping')),
                DropdownMenuItem(value: 'stay', child: Text('Stay & Accommodation')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _category = val;
                    _subcategory = (_subcategoriesMap[val] ?? ['park']).first;
                  });
                }
              },
            ),

            const SizedBox(height: AppSpacing.md),

            DropdownButtonFormField<String>(
              value: subcategories.contains(_subcategory) ? _subcategory : subcategories.first,
              decoration: const InputDecoration(labelText: 'Subcategory'),
              items: subcategories.map((sub) {
                return DropdownMenuItem(
                  value: sub,
                  child: Text(sub.replaceAll('_', ' ')),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _subcategory = val);
              },
            ),

            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe what visitors can expect, unique features, or local tips.',
              ),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a description.' : null,
            ),

            const SizedBox(height: AppSpacing.sectionGap),

            // Location Section
            JdqSectionHeader(
              title: '3. Location',
              subtitle: 'Municipality and approximate GPS coordinates.',
            ),

            TextFormField(
              controller: _muniController,
              decoration: const InputDecoration(labelText: 'Municipality'),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a municipality.' : null,
            ),

            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address / Landmark',
                hintText: 'e.g. Patar Road, Brgy. Patar',
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'GPS Latitude'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'GPS Longitude'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sectionGap),

            if (_submitError != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: AppSpacing.roundedMd,
                ),
                child: Text(
                  _submitError!,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.danger),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            PrimaryButton(
              label: 'Submit for Community Review',
              onPressed: (_submitting || _uploading) ? null : _submitSpot,
              isLoading: _submitting,
              icon: Icons.send_rounded,
            ),

            const SizedBox(height: AppSpacing.sectionGap),
          ],
        ),
      ),
    );
  }
}
