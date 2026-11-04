import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../models/campaign_model.dart';
import '../providers/campaign_provider.dart';

class CampaignDetailScreen extends ConsumerStatefulWidget {
  final String campaignId;
  final CampaignModel? initialCampaign;

  const CampaignDetailScreen({
    super.key,
    required this.campaignId,
    this.initialCampaign,
  });

  @override
  ConsumerState<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialCampaign == null) {
      Future.microtask(() {
        if (mounted) ref.read(campaignProvider.notifier).fetchCampaigns();
      });
    }
  }

  Map<String, int> _calculateTimeRemaining(String dateString) {
    try {
      final target = DateTime.parse(dateString);
      final diff = target.difference(DateTime.now());
      if (diff.isNegative) {
        return {'days': 0, 'hours': 0, 'minutes': 0};
      }
      return {
        'days': diff.inDays,
        'hours': diff.inHours % 24,
        'minutes': diff.inMinutes % 60,
      };
    } catch (_) {
      return {'days': 14, 'hours': 8, 'minutes': 30};
    }
  }

  Future<void> _reload() =>
      ref.read(campaignProvider.notifier).fetchCampaigns(forceRefresh: true);

  @override
  Widget build(BuildContext context) {
    final campaignState = ref.watch(campaignProvider);
    CampaignModel? campaign = widget.initialCampaign?.id == widget.campaignId
        ? widget.initialCampaign
        : null;
    for (final item in campaignState.campaigns) {
      if (item.id == widget.campaignId) campaign = item;
    }
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Event Campaign',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: campaign == null
                        ? _missing(context, grid, campaignState)
                        : _campaign(context, grid, campaign),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _missing(
      BuildContext context, PixelGrid grid, CampaignState state) {
    if (!state.hasLoaded || state.isLoading) {
      return const Center(child: PixelLoader(label: 'Loading campaign'));
    }
    if (state.failure != null) {
      return ListView(
        padding: EdgeInsets.all(grid.px(4)),
        children: [
          PixelPanel(
            style: PixelBoxStyle.red,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campaigns are unavailable.',
                  style: PixelType.title(context, color: PixelPalette.white),
                ),
                SizedBox(height: grid.px(2)),
                Text(
                  'Check your connection.',
                  style: PixelType.body(context, color: PixelPalette.cream),
                ),
                SizedBox(height: grid.px(3)),
                Align(
                  alignment: Alignment.centerRight,
                  child: PixelButton(
                    key: const ValueKey('campaign_retry'),
                    label: 'Retry',
                    onPressed: () => _reload(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Center(
      child: Text('Campaign not found.', style: PixelType.body(context)),
    );
  }

  Widget _campaign(
      BuildContext context, PixelGrid grid, CampaignModel campaign) {
    final timeLeft = _calculateTimeRemaining(campaign.eventDate);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        grid.px(4),
        grid.px(3),
        grid.px(4),
        grid.px(8) + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PixelPanel(
          style: PixelBoxStyle.parchment,
          padding: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: grid.px(90),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRect(
                        child: Image.network(
                          campaign.bannerImageUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => const DitherBackground(
                            top: PixelPalette.sunLight,
                            bottom: PixelPalette.woodMid,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: grid.px(1),
                      right: grid.px(1),
                      child: const PixelChip('Event preview'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: grid.px(2)),
              Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(1),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PixelChip(campaign.municipality,
                      style: PixelBoxStyle.green,
                      textColor: PixelPalette.white),
                  Text(
                    'Organized by ${campaign.hostName}',
                    style: PixelType.body(context, color: PixelPalette.slate),
                  ),
                ],
              ),
              SizedBox(height: grid.px(2)),
              Text(campaign.title, style: PixelType.title(context)),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        PixelPanel(
          style: PixelBoxStyle.wood,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EVENT COUNTDOWN',
                style: PixelType.small(context, color: PixelPalette.sun),
              ),
              SizedBox(height: grid.px(2)),
              Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(2),
                children: [
                  _timeBox(context, grid, '${timeLeft['days']}', 'DAYS'),
                  _timeBox(context, grid, '${timeLeft['hours']}', 'HOURS'),
                  _timeBox(context, grid, '${timeLeft['minutes']}', 'MINS'),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registration and rewards under development',
                style: PixelType.title(context),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                'This event is a preview. No tickets, capacity, or funds are reserved.',
                style: PixelType.body(context, color: PixelPalette.slate),
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        Text('About this Event Campaign',
            style: PixelType.title(context)),
        SizedBox(height: grid.px(1)),
        Text(
          campaign.description,
          style: PixelType.body(context, color: PixelPalette.slate),
        ),
        if (campaign.preQuestRequirements.isNotEmpty) ...[
          SizedBox(height: grid.px(3)),
          Text('Campaign Checkpoint Requirements',
              style: PixelType.title(context)),
          SizedBox(height: grid.px(2)),
          for (final requirement in campaign.preQuestRequirements) ...[
            PixelPanel(
              style: PixelBoxStyle.parchment,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PixelChip('Check', style: PixelBoxStyle.green,
                      textColor: PixelPalette.white),
                  SizedBox(width: grid.px(2)),
                  Expanded(
                    child: Text(
                      requirement,
                      style: PixelType.body(context),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: grid.px(2)),
          ],
        ],
        SizedBox(height: grid.px(2)),
        const PixelButton(
          key: ValueKey('campaign_register_disabled'),
          label: 'Registration under development',
          expand: true,
        ),
      ],
    );
  }

  Widget _timeBox(
      BuildContext context, PixelGrid grid, String value, String unit) {
    return PixelPanel(
      style: PixelBoxStyle.slot,
      child: Column(
        children: [
          Text(
            value.padLeft(2, '0'),
            style: PixelType.title(context, color: PixelPalette.wood),
          ),
          Text(
            unit,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ],
      ),
    );
  }
}
