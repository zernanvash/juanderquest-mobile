import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/campaign_model.dart';

class CampaignState {
  final List<CampaignModel> campaigns;
  final bool isLoading;
  final ApiFailure? failure;

  const CampaignState({
    this.campaigns = const [],
    this.isLoading = false,
    this.failure,
  });

  CampaignState copyWith({
    List<CampaignModel>? campaigns,
    bool? isLoading,
    ApiFailure? failure,
    bool clearFailure = false,
  }) {
    return CampaignState(
      campaigns: campaigns ?? this.campaigns,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class CampaignNotifier extends StateNotifier<CampaignState> {
  final ApiClient _apiClient;

  CampaignNotifier(this._apiClient) : super(const CampaignState());

  static const List<CampaignModel> defaultCampaigns = [
    CampaignModel(
      id: 'bangus-festival-2026',
      hostId: 'dagupan-lgu',
      hostName: 'Dagupan City Tourism Office',
      title: 'Bangus Festival 2026: Gilon-Gilon Street Dance & Grill Quest',
      category: 'cultural',
      locationName: 'Dagupan City Plaza, AB Fernandez Ave',
      municipality: 'Dagupan City',
      bannerImageUrl: 'https://images.unsplash.com/photo-1548625361-16a9a087192a?auto=format&fit=crop&w=1200&q=80',
      description: 'Participate in the legendary Dagupan Bangus street dance, visit 3 heritage checkpoints, and redeem fresh grilled bangus tasting vouchers.',
      eventDate: '2026-09-15T08:00:00Z',
      startDate: '2026-09-01T00:00:00Z',
      endDate: '2026-09-15T22:00:00Z',
      totalBudgetMjdq: 250000,
      rewardPerParticipantMjdq: 1500,
      referralBountyMjdq: 250,
      maxParticipants: 500,
      reservedParticipants: 342,
      completedParticipants: 120,
      preQuestRequirements: [
        'Complete Dagupan Bangus Market Check-in',
        'Take GPS verification at City Museum',
      ],
      gpsLat: 16.0433,
      gpsLng: 120.3340,
      gpsRadiusMeters: 250,
      status: 'active',
      createdAt: '2026-08-01T00:00:00Z',
    ),
    CampaignModel(
      id: 'hundred-islands-eco-rally',
      hostId: 'alaminos-lgu',
      hostName: 'Alaminos City Eco-Tourism Board',
      title: 'Hundred Islands Coastal Eco-Cleanup & Snorkel Trail',
      category: 'eco',
      locationName: 'Lucap Wharf & Quezon Island',
      municipality: 'Alaminos City',
      bannerImageUrl: 'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?auto=format&fit=crop&w=1200&q=80',
      description: 'Help preserve the coral reefs across Governor Island and Quezon Island. Earn verified Eco-Scout Soulbound NFT badge upon completion.',
      eventDate: '2026-10-05T07:00:00Z',
      startDate: '2026-09-20T00:00:00Z',
      endDate: '2026-10-05T18:00:00Z',
      totalBudgetMjdq: 500000,
      rewardPerParticipantMjdq: 2500,
      referralBountyMjdq: 400,
      maxParticipants: 300,
      reservedParticipants: 215,
      completedParticipants: 0,
      preQuestRequirements: [
        'Attend 10-minute Marine Sanctuary Briefing',
        'GPS check-in at Lucap Information Center',
      ],
      gpsLat: 16.2044,
      gpsLng: 120.0406,
      gpsRadiusMeters: 300,
      status: 'active',
      createdAt: '2026-08-10T00:00:00Z',
    ),
    CampaignModel(
      id: 'bolinao-sunset-heritage-run',
      hostId: 'bolinao-tourism',
      hostName: 'Bolinao Municipal Tourism',
      title: 'Cape Bolinao Lighthouse Sunset Trail 10K',
      category: 'sports_adventure',
      locationName: 'Cape Bolinao & Patar Beach Road',
      municipality: 'Bolinao',
      bannerImageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      description: 'Scenic 10K twilight walk/run along the rugged cliffs of Cape Bolinao to Patar White Beach. Unlock MSME coconut refreshment vouchers.',
      eventDate: '2026-11-12T16:00:00Z',
      startDate: '2026-10-15T00:00:00Z',
      endDate: '2026-11-12T20:00:00Z',
      totalBudgetMjdq: 300000,
      rewardPerParticipantMjdq: 1800,
      referralBountyMjdq: 300,
      maxParticipants: 400,
      reservedParticipants: 180,
      completedParticipants: 0,
      preQuestRequirements: [
        'Check-in at Cape Bolinao Base Marker',
      ],
      gpsLat: 16.3075,
      gpsLng: 119.7892,
      gpsRadiusMeters: 200,
      status: 'active',
      createdAt: '2026-08-15T00:00:00Z',
    ),
  ];

  Future<void> fetchCampaigns({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final response = await _apiClient.dio.get('/campaigns');
      if (response.data != null && response.data['success'] == true) {
        final rawList = response.data['data'] as List?;
        if (rawList != null && rawList.isNotEmpty) {
          final items = rawList.map((e) => CampaignModel.fromJson(e as Map<String, dynamic>)).toList();
          state = state.copyWith(campaigns: items, isLoading: false);
          return;
        }
      }
      // Fallback to seeded prototype campaigns if endpoint is empty
      state = state.copyWith(campaigns: defaultCampaigns, isLoading: false);
    } catch (_) {
      // Graceful fallback for offline prototype testing
      state = state.copyWith(campaigns: defaultCampaigns, isLoading: false);
    }
  }
}

final campaignProvider = StateNotifierProvider<CampaignNotifier, CampaignState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CampaignNotifier(apiClient);
});
