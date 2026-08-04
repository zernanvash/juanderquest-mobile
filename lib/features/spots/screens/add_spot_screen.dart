import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

      // Auto-upload photo if picked but not yet uploaded
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
            const SnackBar(content: Text('Destination spot added successfully!')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Destination Spot'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Card(
                  color: Color(0xFFE8F5E9),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user, color: Color(0xFF2E7D32)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Community Destination Submission',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Photo Selector & Preview
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Destination Photo (Max 8 MB)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (_selectedFile != null)
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
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
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle, size: 14, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'Uploaded',
                                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                SizedBox(height: 6),
                                Text('Select a photo from camera or gallery', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        if (_uploading) ...[
                          LinearProgressIndicator(value: _uploadProgress > 0 ? _uploadProgress : null),
                          const SizedBox(height: 6),
                          Text('Uploading photo... ${(_uploadProgress * 100).toInt()}%', style: const TextStyle(fontSize: 11)),
                        ],

                        if (_uploadError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_uploadError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ),

                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                            ),
                            if (_selectedFile != null && _uploadedAssetId == null)
                              FilledButton.icon(
                                onPressed: _uploading ? null : _uploadPhoto,
                                icon: const Icon(Icons.cloud_upload),
                                label: const Text('Upload'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Destination Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Enter at least 3 characters' : null,
                ),
                const SizedBox(height: 12),

                // Category & Subcategory
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                  items: _subcategoriesMap.keys
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.replaceAll('_', ' ').toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _category = val;
                        _subcategory = _subcategoriesMap[val]!.first;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _subcategory,
                  decoration: const InputDecoration(labelText: 'Subcategory *', border: OutlineInputBorder()),
                  items: subcategories
                      .map((sub) => DropdownMenuItem(
                            value: sub,
                            child: Text(sub.replaceAll('_', ' ')),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _subcategory = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 20) ? 'Enter at least 20 characters' : null,
                ),
                const SizedBox(height: 12),

                // Municipality & Address
                TextFormField(
                  controller: _muniController,
                  decoration: const InputDecoration(labelText: 'Municipality / City *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'GPS Lat', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'GPS Lng', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_submitError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _submitError!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),

                FilledButton(
                  onPressed: (_submitting || _uploading) ? null : _submitSpot,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Submit Destination Spot', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
