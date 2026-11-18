import 'package:flutter/material.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';

class SponsorshipConditionData {
  const SponsorshipConditionData({
    required this.type,
    this.value,
    this.met = false,
    this.detail = '',
  });

  final String type;
  final int? value;

  /// `true`, `false`, or `'unknown'`.
  final Object met;
  final String detail;

  bool get isMet => met == true;
  bool get isUnknown => met == 'unknown';

  factory SponsorshipConditionData.fromJson(Map<String, dynamic> json) {
    final rawMet = json['met'];
    final Object parsedMet =
        rawMet == true ? true : (rawMet == 'unknown' ? 'unknown' : false);
    final rawValue = json['value'];
    return SponsorshipConditionData(
      type: json['type']?.toString() ?? '',
      value: rawValue is num ? rawValue.toInt() : int.tryParse('$rawValue'),
      met: parsedMet,
      detail: json['detail']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toInputJson() => {
        'type': type,
        if (type == 'min_players') 'value': value ?? 1,
      };
}

/// Pure pixel-art status glyphs (no colour emoji) using the documented palette.
abstract final class _ConditionMarkArt {
  static const check = PixelArt('condCheck', [
    '.......',
    '.....a.',
    '....aa.',
    '.a.aa..',
    '.aaa...',
    '..a....',
    '.......',
  ]);

  static const cross = PixelArt('condCross', [
    '.......',
    '.s...s.',
    '..s.s..',
    '...s...',
    '..s.s..',
    '.s...s.',
    '.......',
  ]);

  static const unknown = PixelArt('condUnknown', [
    '..fff..',
    '.f...f.',
    '....f..',
    '...f...',
    '...f...',
    '.......',
    '...f...',
  ]);
}

class PixelConditionMark extends StatelessWidget {
  const PixelConditionMark({super.key, required this.met});

  /// `true`, `false`, or `'unknown'`.
  final Object met;

  @override
  Widget build(BuildContext context) {
    final art = met == true
        ? _ConditionMarkArt.check
        : met == 'unknown'
            ? _ConditionMarkArt.unknown
            : _ConditionMarkArt.cross;
    final label =
        met == true ? 'Met' : (met == 'unknown' ? 'Unknown' : 'Unmet');
    return SizedBox.square(
      dimension: 14,
      child: FittedBox(
        child: PixelSprite(art, scale: 2, semanticLabel: label),
      ),
    );
  }
}

String conditionLabelText(BuildContext context, String type, int? value) {
  switch (type) {
    case 'same_town':
      return tr(
        context,
        en: 'Same town as shop',
        tl: 'Parehong bayan ng tindahan',
      );
    case 'visits_shop':
      return tr(
        context,
        en: 'Quest visits shop (within 300 m)',
        tl: 'Bumisita ang quest sa tindahan (300 m)',
      );
    case 'min_players':
      final count = value ?? 1;
      return tr(
        context,
        en: 'Minimum $count completed players',
        tl: 'Hindi bababa sa $count manlalaro ang nakatapos',
      );
    case 'creator_good_standing':
      return tr(
        context,
        en: 'Verified creator in good standing',
        tl: 'Beripikado at maayos ang reputasyon ng lumikha',
      );
    default:
      return type;
  }
}

class SponsorshipConditionsList extends StatelessWidget {
  const SponsorshipConditionsList({
    super.key,
    required this.conditions,
    this.textColor = PixelPalette.ink,
    this.detailColor = PixelPalette.slate,
  });

  final List<SponsorshipConditionData> conditions;
  final Color textColor;
  final Color detailColor;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final cond in conditions)
          Padding(
            padding: EdgeInsets.only(bottom: grid.px(1)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: PixelConditionMark(met: cond.met),
                ),
                SizedBox(width: grid.px(1.5)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conditionLabelText(context, cond.type, cond.value),
                        style: PixelType.small(context, color: textColor)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (cond.detail.isNotEmpty)
                        Text(
                          cond.detail,
                          style: PixelType.small(context, color: detailColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<List<Map<String, dynamic>>?> showSetConditionsSheet(
  BuildContext context, {
  List<SponsorshipConditionData> initial = const [],
}) {
  return showModalBottomSheet<List<Map<String, dynamic>>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _SetConditionsSheet(initial: initial),
  );
}

class _SetConditionsSheet extends StatefulWidget {
  const _SetConditionsSheet({required this.initial});

  final List<SponsorshipConditionData> initial;

  @override
  State<_SetConditionsSheet> createState() => _SetConditionsSheetState();
}

class _SetConditionsSheetState extends State<_SetConditionsSheet> {
  late bool _sameTown;
  late bool _visitsShop;
  late bool _minPlayers;
  late bool _creatorStanding;
  late final TextEditingController _playersController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final types = {for (final c in widget.initial) c.type: c};
    _sameTown = types.containsKey('same_town');
    _visitsShop = types.containsKey('visits_shop');
    _minPlayers = types.containsKey('min_players');
    _creatorStanding = types.containsKey('creator_good_standing');
    final initialPlayers = types['min_players']?.value ?? 5;
    _playersController = TextEditingController(text: '$initialPlayers');
  }

  @override
  void dispose() {
    _playersController.dispose();
    super.dispose();
  }

  void _save() {
    final result = <Map<String, dynamic>>[];
    if (_sameTown) result.add({'type': 'same_town'});
    if (_visitsShop) result.add({'type': 'visits_shop'});
    if (_minPlayers) {
      final parsed = int.tryParse(_playersController.text.trim());
      if (parsed == null || parsed < 1 || parsed > 1000) {
        setState(
          () => _validationError = tr(
            context,
            en: 'Enter players between 1 and 1000.',
            tl: 'Maglagay ng bilang mula 1 hanggang 1000.',
          ),
        );
        return;
      }
      result.add({'type': 'min_players', 'value': parsed});
    }
    if (_creatorStanding) result.add({'type': 'creator_good_standing'});
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: grid.gutter,
                right: grid.gutter,
                top: grid.px(3),
                bottom: MediaQuery.viewInsetsOf(context).bottom + grid.px(2),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: PixelPanel(
                  style: PixelBoxStyle.parchment,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr(
                          context,
                          en: 'DEAL CONDITIONS',
                          tl: 'MGA KONDISYON SA KASUNDUAN',
                        ),
                        style: PixelType.title(context),
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        tr(
                          context,
                          en: 'Server checks each requirement before accept.',
                          tl: 'Sinusuri ng server ang bawat kondisyon bago tanggapin.',
                        ),
                        style:
                            PixelType.small(context, color: PixelPalette.slate),
                      ),
                      SizedBox(height: grid.px(2)),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PixelCheckbox(
                                key: const ValueKey('cond_same_town'),
                                value: _sameTown,
                                label: tr(
                                  context,
                                  en: 'Same town as shop',
                                  tl: 'Parehong bayan ng tindahan',
                                ),
                                onChanged: (v) => setState(() => _sameTown = v),
                              ),
                              PixelCheckbox(
                                key: const ValueKey('cond_visits_shop'),
                                value: _visitsShop,
                                label: tr(
                                  context,
                                  en: 'Quest visits shop (<= 300 m)',
                                  tl: 'Bumisita ang quest sa tindahan (<= 300 m)',
                                ),
                                onChanged: (v) =>
                                    setState(() => _visitsShop = v),
                              ),
                              PixelCheckbox(
                                key: const ValueKey('cond_min_players'),
                                value: _minPlayers,
                                label: tr(
                                  context,
                                  en: 'Minimum players completed',
                                  tl: 'Minimum na nakatapos na manlalaro',
                                ),
                                onChanged: (v) => setState(() {
                                  _minPlayers = v;
                                  _validationError = null;
                                }),
                              ),
                              if (_minPlayers) ...[
                                SizedBox(height: grid.px(1)),
                                PixelTextField(
                                  key: const ValueKey('cond_min_players_value'),
                                  controller: _playersController,
                                  label: tr(
                                    context,
                                    en: 'Players required (1–1000)',
                                    tl: 'Kailangang manlalaro (1–1000)',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                              PixelCheckbox(
                                key: const ValueKey('cond_creator_standing'),
                                value: _creatorStanding,
                                label: tr(
                                  context,
                                  en: 'Creator in good standing',
                                  tl: 'Maayos ang reputasyon ng lumikha',
                                ),
                                onChanged: (v) =>
                                    setState(() => _creatorStanding = v),
                              ),
                              if (_validationError != null) ...[
                                SizedBox(height: grid.px(1)),
                                Text(
                                  _validationError!,
                                  style: PixelType.small(
                                    context,
                                    color: PixelPalette.redDeep,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: grid.px(2)),
                      // Sticky non-scrolling footer so actions stay visible at 2x text.
                      Wrap(
                        spacing: grid.px(2),
                        runSpacing: grid.px(1.5),
                        alignment: WrapAlignment.end,
                        children: [
                          PixelButton(
                            key: const ValueKey('cond_sheet_cancel'),
                            label: tr(context, en: 'CANCEL', tl: 'KANSELAHIN'),
                            variant: PixelButtonVariant.secondary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          PixelButton(
                            key: const ValueKey('cond_sheet_save'),
                            label: tr(
                              context,
                              en: 'SAVE CONDITIONS',
                              tl: 'I-SAVE ANG KONDISYON',
                            ),
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String formatSponsoredByNames(
  List<String> names, {
  String by = 'Sponsored by',
  String and = 'and',
}) {
  if (names.isEmpty) return '';
  if (names.length == 1) return '$by ${names[0]}';
  if (names.length == 2) return '$by ${names[0]} $and ${names[1]}';
  return '$by ${names[0]}, ${names[1]} +${names.length - 2}';
}

class SponsoredByLine extends StatelessWidget {
  const SponsoredByLine({
    super.key,
    required this.names,
    this.logoUrl,
    this.textColor = PixelPalette.sunLight,
    this.onTap,
  });

  final List<String> names;
  final String? logoUrl;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final grid = PixelGrid.of(context);
    final label = formatSponsoredByNames(
      names,
      by: tr(context, en: 'Sponsored by', tl: 'Itinataguyod ng'),
      and: tr(context, en: 'and', tl: 'at'),
    );
    final hasLogo = logoUrl != null && logoUrl!.trim().isNotEmpty;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasLogo) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.network(
              logoUrl!,
              width: 16,
              height: 16,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.square(
                dimension: 16,
                child: FittedBox(
                  child: PixelSprite(DesignerArt.handshake, scale: 1),
                ),
              ),
            ),
          ),
          SizedBox(width: grid.px(1)),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PixelType.small(context, color: textColor).copyWith(
              fontWeight: FontWeight.w700,
              decoration: onTap != null ? TextDecoration.underline : null,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}
