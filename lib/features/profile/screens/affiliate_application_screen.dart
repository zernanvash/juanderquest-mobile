import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';

const _affiliateCategories = <String>[
  'dining',
  'pasalubong',
  'lodging',
  'adventure',
  'heritage',
  'retail'
];
const _affiliateGoals = <String, String>{
  'quest_stop': 'Co-sponsor a tourism quest stop',
  'voucher_perk': 'Offer voucher perks or discounts',
  'map_pin': 'Request a business map feature',
  'event_sponsor': 'Support a festival or seasonal event',
};

class AffiliateApplicationScreen extends ConsumerStatefulWidget {
  const AffiliateApplicationScreen({super.key});

  @override
  ConsumerState<AffiliateApplicationScreen> createState() =>
      _AffiliateApplicationScreenState();
}

class _AffiliateApplicationScreenState
    extends ConsumerState<AffiliateApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _municipality = TextEditingController(text: 'Dagupan City');
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _details = TextEditingController();
  String _category = _affiliateCategories.first;
  final Set<String> _goals = {};
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _existing;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadApplication);
  }

  @override
  void dispose() {
    _business.dispose();
    _municipality.dispose();
    _contact.dispose();
    _email.dispose();
    _phone.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _loadApplication() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/affiliate/applications/me');
      final data = response.data is Map ? response.data['data'] : null;
      if (data is Map<String, dynamic> && mounted) {
        setState(() {
          _existing = data;
          _business.text = data['business_name']?.toString() ?? '';
          _category = _affiliateCategories.contains(data['category'])
              ? data['category'] as String
              : _category;
          _municipality.text =
              data['municipality']?.toString() ?? _municipality.text;
          _contact.text = data['contact_name']?.toString() ?? '';
          _email.text = data['contact_email']?.toString() ?? '';
          _phone.text = data['contact_phone']?.toString() ?? '';
          _details.text = data['proposal_details']?.toString() ?? '';
          _goals.addAll((data['sponsorship_goals'] as List? ?? const [])
              .whereType<String>());
        });
      }
    } catch (_) {
      // The application form remains useful if the optional status read fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_goals.isEmpty) {
      setState(() =>
          _error = 'Choose at least one way you would like to participate.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .post('/affiliate/applications', data: {
        'business_name': _business.text.trim(),
        'category': _category,
        'municipality': _municipality.text.trim(),
        'contact_name': _contact.text.trim(),
        'contact_email': _email.text.trim(),
        'contact_phone': _phone.text.trim(),
        'sponsorship_goals': _goals.toList(),
        'proposal_details': _details.text.trim(),
      });
      if (mounted) {
        setState(() {
          _existing = response.data['data'] is Map
              ? Map<String, dynamic>.from(response.data['data'] as Map)
              : _existing;
          _success = 'Your application was submitted for review.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Could not submit the application. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _existing?['status']?.toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Affiliate')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text('Partner with local tourism',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: AppColors.woodBrown)),
                  const SizedBox(height: 8),
                  const Text(
                      'Local businesses can apply to participate in destination quests, vouchers, map discovery, and seasonal events. Applications are reviewed by the team.'),
                  if (status != null) ...[
                    const SizedBox(height: 12),
                    Card(
                        child: ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('Application status'),
                            subtitle: Text(status.replaceAll('_', ' ')))),
                  ],
                  const SizedBox(height: 18),
                  _field(_business, 'Business name'),
                  DropdownButtonFormField<String>(
                      value: _category,
                      decoration:
                          const InputDecoration(labelText: 'Business category'),
                      items: _affiliateCategories
                          .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(v, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category)),
                  _field(_municipality, 'Municipality / city'),
                  _field(_contact, 'Contact person'),
                  _field(_email, 'Contact email',
                      type: TextInputType.emailAddress),
                  _field(_phone, 'Contact phone', type: TextInputType.phone),
                  const SizedBox(height: 12),
                  Text('How would you like to participate?',
                      style: Theme.of(context).textTheme.titleMedium),
                  ..._affiliateGoals.entries.map((entry) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        value: _goals.contains(entry.key),
                        onChanged: (selected) => setState(() => selected == true
                            ? _goals.add(entry.key)
                            : _goals.remove(entry.key)),
                      )),
                  _field(_details, 'Proposal details (optional)',
                      required: false, maxLines: 4),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red))),
                  if (_success != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(_success!,
                            style: const TextStyle(color: AppColors.primary))),
                  const SizedBox(height: 8),
                  PrimaryButton(
                      label: _submitting
                          ? 'Submitting…'
                          : status == 'received' || status == 'in_review'
                              ? 'Application Under Review'
                              : 'Submit Application',
                      onPressed: _submitting ||
                              status == 'received' ||
                              status == 'in_review'
                          ? null
                          : _submit),
                  const SizedBox(height: 12),
                  Text(
                      'Submitting an application does not guarantee approval. Voucher offers and merchant spending remain subject to separate review.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label,
          {TextInputType? type, bool required = true, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label,
              border:
                  const OutlineInputBorder(borderRadius: AppSpacing.roundedMd)),
          validator: !required
              ? null
              : (value) => value == null || value.trim().length < 2
                  ? 'Enter $label'
                  : null,
        ),
      );
}
