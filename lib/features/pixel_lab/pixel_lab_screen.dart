import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_art.dart';
import '../../core/pixel/pixel_background.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_input.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/pixel/pixel_theme.dart';
import '../../core/theme/app_theme.dart';
import '../celebrations/celebration.dart';
import '../dashboard/home_tips.dart';
import '../spots/theater/theater_backdrop.dart';
import 'home_options.dart';
import 'rpg_feel_section.dart';
import 'tutorial_preview.dart';

class PixelLabScreen extends ConsumerStatefulWidget {
  const PixelLabScreen({super.key});

  @override
  ConsumerState<PixelLabScreen> createState() => _PixelLabScreenState();
}

class _PixelLabScreenState extends ConsumerState<PixelLabScreen> {
  final _textController = TextEditingController();
  final _errorController = TextEditingController(text: 'Manaoag');
  final _requiredFormKey = GlobalKey<FormState>();

  bool _switchOn = true;
  bool _checked = true;
  int _radio = 0;
  int _segment = 0;
  double _slider = 0.6;
  int _hotbar = 0;
  bool _showError = true;
  String _dialogResult = 'NO DIALOG YET';
  bool _liked = false;
  bool _playLike = false;

  @override
  void dispose() {
    _textController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  String _sizeLabel(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(pixelSettingsProvider);
    final notifier = ref.read(pixelSettingsProvider.notifier);
    return PixelScope(
      settings: settings,
      child: Theme(
        data: AppTheme.pixel,
        child: Builder(
          builder: (context) {
            final grid = PixelGrid.of(context);
            return Scaffold(
              backgroundColor: PixelPalette.woodDeep,
              body: DitherBackground(
                top: PixelPalette.wood,
                bottom: PixelPalette.woodDeep,
                child: Column(
                  children: [
                    PixelAppBar(
                      title: 'Pixel lab',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(grid.px(4)),
                        children: [
                          _intro(context, grid),
                          if (!kReleaseMode) ...[
                            SizedBox(height: grid.px(3)),
                            _kit(context, grid, settings, notifier),
                          ],
                          SizedBox(height: grid.px(3)),
                          _readableText(context, grid, settings),
                          SizedBox(height: grid.px(3)),
                          _section(context, 'RPG feel (75k)',
                              const RpgFeelSection()),
                          SizedBox(height: grid.px(3)),
                          _spotBackdrop(context, grid),
                          SizedBox(height: grid.px(3)),
                          _homeOptions(context, grid),
                          SizedBox(height: grid.px(3)),
                          _palette(context, grid),
                          SizedBox(height: grid.px(3)),
                          _panels(context, grid),
                          SizedBox(height: grid.px(3)),
                          _buttons(context, grid),
                          SizedBox(height: grid.px(3)),
                          _toggles(context, grid),
                          SizedBox(height: grid.px(3)),
                          _inputs(context, grid),
                          SizedBox(height: grid.px(3)),
                          _feedback(context, grid),
                          SizedBox(height: grid.px(3)),
                          _navigation(context, grid),
                          SizedBox(height: grid.px(3)),
                          _sprites(context, grid, settings),
                          SizedBox(height: grid.px(3)),
                          _celebrations(context, grid),
                          SizedBox(height: grid.px(3)),
                          _tutorials(context, grid),
                          SizedBox(height: grid.px(6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _spotBackdrop(BuildContext context, PixelGrid grid) {
    final current = ref.watch(theaterBackdropProvider);
    return _section(
      context,
      'Spot page background · pick one',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What the place photo looks like behind the details once you '
            'scroll down. Open any place in Explore to see it.',
            style: PixelType.small(context, color: PixelPalette.ink),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            children: [
              for (final mode in TheaterBackdrop.values)
                PixelButton(
                  key: ValueKey('lab_backdrop_${mode.name}'),
                  label: mode.label,
                  variant: mode == current
                      ? PixelButtonVariant.primary
                      : PixelButtonVariant.secondary,
                  onPressed: () =>
                      ref.read(theaterBackdropProvider.notifier).state = mode,
                ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(
            current.hint,
            style: PixelType.small(context, color: PixelPalette.woodDeep),
          ),
        ],
      ),
    );
  }

  Widget _homeOptions(BuildContext context, PixelGrid grid) {
    return _section(
      context,
      'Home layout · pick one',
      const HomeOptionsSection(),
    );
  }

  Widget _intro(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.inkDialogue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShadowText(
            'PIXEL KIT · EVERYTHING DRAWN WITH MATH',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(2)),
          Text(
            'ONE ART PIXEL = ${grid.devicePerArt} DEVICE PIXELS. '
            'NO GRADIENTS, NO BLUR, NO ROUNDED CORNERS.',
            style: PixelType.body(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'DEBUG/PROFILE KIT IS LIVE; RELEASE BUILDS FIX 2 AND SILKSCREEN.',
            style: PixelType.small(context, color: PixelPalette.sun),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    Widget child, {
    PixelBoxStyle style = PixelBoxStyle.parchment,
    Color titleColor = PixelPalette.ink,
  }) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: style,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShadowText(
            title.toUpperCase(),
            style: PixelType.title(context, color: titleColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: grid.px(2)),
          child,
        ],
      ),
    );
  }

  Widget _kit(
    BuildContext context,
    PixelGrid grid,
    PixelSettings settings,
    PixelSettingsNotifier notifier,
  ) {
    return _section(
      context,
      'Kit',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ART PIXEL SIZE · 1 ART PX = ${grid.devicePerArt} SCREEN PX',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            children: [
              for (final value in PixelSettings.artSizes)
                PixelButton(
                  label: _sizeLabel(value),
                  variant: settings.artPx == value
                      ? PixelButtonVariant.primary
                      : PixelButtonVariant.secondary,
                  onPressed: () => notifier.setArtPx(value),
                ),
            ],
          ),
          SizedBox(height: grid.px(3)),
          Text(
            'FONT · UNIFORM ACROSS THE APP',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          for (final entry in PixelSettings.fonts.entries) ...[
            Semantics(
              button: true,
              selected: settings.font == entry.key,
              label: entry.key,
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: () {
                    pixelTick(context);
                    notifier.setFont(entry.key);
                  },
                  child: PixelPanel(
                    style: settings.font == entry.key
                        ? PixelBoxStyle.gold
                        : PixelBoxStyle.slot,
                    sunken: settings.font != entry.key,
                    padding: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: entry.key,
                            fontSize: 16,
                            height: 1.3,
                            color: PixelPalette.ink,
                          ),
                        ),
                        Text(
                          'Hundred Islands · 1,250 mJDQ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: entry.key,
                            fontSize: 12,
                            height: 1.3,
                            color: PixelPalette.wood,
                          ),
                        ),
                        Text(
                          entry.value,
                          style: PixelType.small(
                            context,
                            color: PixelPalette.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: grid.px(2)),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'HAPTIC CLICK',
                  style: PixelType.body(context),
                ),
              ),
              PixelSwitch(
                value: settings.haptics,
                onChanged: notifier.setHaptics,
                semanticLabel: 'Haptic click',
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            label: 'Reset kit',
            variant: PixelButtonVariant.secondary,
            onPressed: notifier.reset,
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            label: 'Replay first-run tutorial',
            variant: PixelButtonVariant.secondary,
            onPressed: () async {
              await ref
                  .read(homeTipsControllerProvider.notifier)
                  .resetForReplay();
              if (context.mounted) {
                showPixelToast(context, 'THE TUTORIAL SHOWS AGAIN ON HOME');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _readableText(
    BuildContext context,
    PixelGrid grid,
    PixelSettings settings,
  ) {
    return _section(
      context,
      'Readable text (Hypixel style)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'COMPARE TYPE READABILITY ACROSS ALL BUNDLED FONTS AT CURRENT TEXT SCALE',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          for (final family in PixelFonts.families) ...[
            PixelPanel(
              style: settings.font == family
                  ? PixelBoxStyle.gold
                  : PixelBoxStyle.parchment,
              padding: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          family,
                          style: TextStyle(
                            fontFamily: family,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PixelPalette.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (settings.font == family)
                        const PixelChip(
                          'Active',
                          style: PixelBoxStyle.green,
                          textColor: PixelPalette.white,
                        ),
                    ],
                  ),
                  SizedBox(height: grid.px(2)),
                  // Hypixel-style tooltip box
                  PixelPanel(
                    style: PixelBoxStyle.tooltip,
                    padding: 2,
                    child: Padding(
                      padding: EdgeInsets.all(grid.px(2)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Mayor Cole ',
                                  style: TextStyle(
                                    fontFamily: family,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: PixelPalette.gold,
                                  ),
                                ),
                                TextSpan(
                                  text: '(Mining Festival)',
                                  style: TextStyle(
                                    fontFamily: family,
                                    fontSize: 11,
                                    color: PixelPalette.paperDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: grid.px(1)),
                          Divider(height: grid.px(1), color: PixelPalette.stone),
                          SizedBox(height: grid.px(1)),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Purse: ',
                                  style: TextStyle(
                                    fontFamily: family,
                                    fontSize: 12,
                                    color: PixelPalette.stone,
                                  ),
                                ),
                                TextSpan(
                                  text: '810,005 coins',
                                  style: TextStyle(
                                    fontFamily: family,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: PixelPalette.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: grid.px(1)),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Votes: ',
                                  style: TextStyle(
                                    fontFamily: family,
                                    fontSize: 12,
                                    color: PixelPalette.stone,
                                  ),
                                ),
                                TextSpan(
                                  text: '42,109 (61%)',
                                  style: TextStyle(
                                    fontFamily: family,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: PixelPalette.greenBright,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: grid.px(1)),
                          Divider(height: grid.px(1), color: PixelPalette.stone),
                          SizedBox(height: grid.px(1)),
                          Text(
                            'Click to cast your vote for Cole!',
                            style: TextStyle(
                              fontFamily: family,
                              fontSize: 11,
                              color: PixelPalette.sun,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: grid.px(2)),
                  // Sample readable paragraph
                  PixelPanel(
                    style: PixelBoxStyle.slot,
                    sunken: true,
                    padding: 2,
                    child: Padding(
                      padding: EdgeInsets.all(grid.px(1)),
                      child: Text(
                        'Hundred Islands National Park spans 124 pristine islands off Alaminos. '
                        'Explore Gov. Island, scout Quezon Beach, and earn +40 mJDQ while discovering Pangasinan heritage.',
                        style: TextStyle(
                          fontFamily: family,
                          fontSize: 12,
                          height: 1.3,
                          color: PixelPalette.paper,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: grid.px(2)),
          ],
        ],
      ),
    );
  }

  Widget _palette(BuildContext context, PixelGrid grid) {
    return _section(
      context,
      'Palette · ${PixelPalette.names.length} colours',
      Wrap(
        spacing: grid.px(1),
        runSpacing: grid.px(1),
        children: [
          for (final entry in PixelPalette.names.entries)
            Tooltip(
              message: entry.key,
              child: Container(
                width: grid.px(8),
                height: grid.px(8),
                decoration: BoxDecoration(
                  color: entry.value,
                  border: Border.all(
                    color: PixelPalette.ink,
                    width: grid.unit,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panels(BuildContext context, PixelGrid grid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          context,
          'Light panel · parchment',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BODY COPY ON WARM PAPER. EVERY EDGE STEPS BY WHOLE ART PIXELS.',
                style: PixelType.body(context),
              ),
              SizedBox(height: grid.px(2)),
              Text(
                'SECONDARY COPY USES SLATE FOR A SOFTER READ.',
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              SizedBox(height: grid.px(3)),
              const PixelProgressBar(value: 0.8),
              SizedBox(height: grid.px(2)),
              const PixelProgressBar(
                value: 0.45,
                segments: 5,
                color: PixelPalette.sun,
              ),
              SizedBox(height: grid.px(2)),
              const PixelProgressBar(
                value: 0.2,
                segments: 8,
                color: PixelPalette.red,
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        _section(
          context,
          'Dark panel · ink',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DIALOGUE AND NIGHT PANELS USE THE SAME MATH WITH AN INK FILL.',
                style: PixelType.body(context, color: PixelPalette.paper),
              ),
              SizedBox(height: grid.px(2)),
              Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(2),
                children: const [
                  PixelChip('ECO',
                      style: PixelBoxStyle.green,
                      textColor: PixelPalette.white),
                  PixelChip('+75', style: PixelBoxStyle.gold),
                  PixelChip('NEW',
                      style: PixelBoxStyle.red, textColor: PixelPalette.white),
                  PixelChip('STONE',
                      style: PixelBoxStyle.stone,
                      textColor: PixelPalette.white),
                ],
              ),
            ],
          ),
          style: PixelBoxStyle.inkDialogue,
          titleColor: PixelPalette.paper,
        ),
      ],
    );
  }

  Widget _buttons(BuildContext context, PixelGrid grid) {
    return _section(
      context,
      'Buttons',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PixelButton(
                label: 'Primary',
                icon: DesignerArt.search,
                iconScale: 2,
                onPressed: () {},
              ),
              PixelButton(
                label: 'Secondary',
                variant: PixelButtonVariant.secondary,
                onPressed: () {},
              ),
              PixelButton(
                label: 'Danger',
                variant: PixelButtonVariant.danger,
                onPressed: () {},
              ),
              PixelButton(
                label: 'Ghost',
                variant: PixelButtonVariant.ghost,
                onPressed: () {},
              ),
              const PixelButton(label: 'Disabled'),
              PixelButton(
                label: 'Loading',
                loading: true,
                onPressed: () {},
              ),
            ],
          ),
          SizedBox(height: grid.px(3)),
          Text(
            'ICON BUTTONS',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            children: [
              PixelIconButton(
                icon: DesignerArt.notifBell,
                semanticLabel: 'Notifications',
                onPressed: () {},
              ),
              PixelIconButton(
                icon: DesignerArt.search,
                semanticLabel: 'Search',
                onPressed: () {},
              ),
              PixelIconButton(
                icon: DesignerArt.navShop,
                semanticLabel: 'Shop',
                onPressed: () {},
              ),
              PixelIconButton(
                icon: DesignerArt.navSettings,
                semanticLabel: 'Settings',
                onPressed: () {},
              ),
              const PixelIconButton(
                icon: DesignerArt.navExplore,
                semanticLabel: 'Disabled explore',
              ),
            ],
          ),
          SizedBox(height: grid.px(3)),
          PixelButton(
            label: 'Full width',
            expand: true,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _toggles(BuildContext context, PixelGrid grid) {
    return _section(
      context,
      'Controls',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('SWITCH', style: PixelType.body(context)),
              ),
              PixelSwitch(
                value: _switchOn,
                onChanged: (value) => setState(() => _switchOn = value),
                semanticLabel: 'Demo switch',
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          PixelCheckbox(
            value: _checked,
            label: 'CHECKBOX',
            onChanged: (value) => setState(() => _checked = value),
          ),
          PixelCheckbox(
            value: false,
            label: 'UNCHECKED',
            onChanged: (value) {},
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(3),
            runSpacing: grid.px(1),
            children: [
              PixelRadio(
                selected: _radio == 0,
                label: 'RADIO A',
                onChanged: () => setState(() => _radio = 0),
              ),
              PixelRadio(
                selected: _radio == 1,
                label: 'RADIO B',
                onChanged: () => setState(() => _radio = 1),
              ),
            ],
          ),
          SizedBox(height: grid.px(3)),
          PixelSegmented(
            items: const ['All', 'Nearby', 'Saved'],
            selectedIndex: _segment,
            onChanged: (index) => setState(() => _segment = index),
          ),
          SizedBox(height: grid.px(3)),
          Text(
            'STEPPED SLIDER · ${(_slider * 100).round()}%',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          PixelSlider(
            value: _slider,
            divisions: 10,
            semanticLabel: 'Demo slider',
            onChanged: (value) => setState(() => _slider = value),
          ),
        ],
      ),
    );
  }

  Widget _inputs(BuildContext context, PixelGrid grid) {
    return _section(
      context,
      'Input',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelTextField(
            controller: _textController,
            label: 'Search',
            hint: 'Search a place...',
            helperText: 'SUNKEN SLOT, PIXEL CURSOR.',
          ),
          SizedBox(height: grid.px(3)),
          PixelTextField(
            controller: _errorController,
            label: 'Destination',
            hint: 'Where to?',
            errorText: _showError ? 'Enter a destination' : null,
            helperText: _showError ? null : 'Looks good.',
            onChanged: (_) {},
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            label: _showError ? 'Clear error' : 'Show error',
            variant: PixelButtonVariant.secondary,
            onPressed: () => setState(() => _showError = !_showError),
          ),
          SizedBox(height: grid.px(3)),
          Form(
            key: _requiredFormKey,
            child: PixelTextField(
              label: 'Form field',
              hint: 'Type here',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'This field is required'
                  : null,
            ),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            label: 'Validate form',
            variant: PixelButtonVariant.secondary,
            onPressed: () => _requiredFormKey.currentState?.validate(),
          ),
        ],
      ),
    );
  }

  Widget _feedback(BuildContext context, PixelGrid grid) {
    return _section(
      context,
      'Feedback',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            children: [
              PixelButton(
                label: 'Toast',
                variant: PixelButtonVariant.secondary,
                onPressed: () => showPixelToast(context, 'QUEST SAVED'),
              ),
              PixelButton(
                label: 'Dialog',
                variant: PixelButtonVariant.secondary,
                onPressed: _openDialog,
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(
            _dialogResult,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(3)),
          Row(
            children: [
              const PixelLoader(),
              SizedBox(width: grid.px(2)),
              Text('LOADER', style: PixelType.body(context)),
            ],
          ),
          SizedBox(height: grid.px(3)),
          PixelDialogue(
            speaker: 'Juan',
            portrait: DesignerArt.juanIdle.frames.first,
            lines: const [
              'Salakot on. Ready to roam?',
              'Tap to skip. One more tap for the next line.',
            ],
          ),
          SizedBox(height: grid.px(3)),
          PixelEmptyState(
            icon: DesignerArt.search,
            title: 'Nothing here yet',
            message: 'Explore Pangasinan and be the first to post a spot.',
            action: PixelButton(
              label: 'Explore',
              variant: PixelButtonVariant.secondary,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDialog() async {
    final result = await showPixelDialog<bool>(
      context: context,
      title: 'Leave the quest?',
      message: 'Your progress is saved.',
      actions: [
        PixelButton(
          label: 'Stay',
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PixelButton(
          label: 'Leave',
          variant: PixelButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (!mounted) return;
    setState(
        () => _dialogResult = result == true ? 'LEFT THE QUEST' : 'STAYED');
  }

  Widget _navigation(BuildContext context, PixelGrid grid) {
    return _section(
      context,
      'Navigation',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE APP BAR IS SHOWN AT THE TOP OF THIS SCREEN. '
            'THE HOTBAR BELOW IS THE BOTTOM NAVIGATION.',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          PixelHotbar(
            index: _hotbar,
            onTap: (index) => setState(() => _hotbar = index),
            items: const [
              PixelHotbarItem(label: 'Explore', icon: DesignerArt.navExplore),
              PixelHotbarItem(label: 'Shop', icon: DesignerArt.navShop),
              PixelHotbarItem(label: 'Settings', icon: DesignerArt.navSettings),
              PixelHotbarItem(label: 'Quests', icon: DesignerArt.notifBell),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sprites(
      BuildContext context, PixelGrid grid, PixelSettings settings) {
    final stills =
        DesignerArt.all.entries.where((entry) => entry.value is PixelArt);
    final animations =
        DesignerArt.all.entries.where((entry) => entry.value is PixelFrames);
    Widget cell(String name, Widget child) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: grid.px(48)),
          child: Padding(
            padding: EdgeInsets.all(grid.px(2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                child,
                SizedBox(height: grid.px(1)),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
              ],
            ),
          ),
        );
    return _section(
      context,
      'Designer art',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPRITES USE WHOLE-NUMBER SCALES AND NEAREST-NEIGHBOUR.',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          Text('TRY IT · LIKE', style: PixelType.body(context)),
          SizedBox(height: grid.px(1)),
          Row(
            children: [
              GestureDetector(
                key: const ValueKey('pixel_lab_like'),
                onTap: () => setState(() {
                  _liked = !_liked;
                  _playLike = true;
                }),
                child: _playLike
                    ? PixelAnimation(
                        _liked
                            ? DesignerArt.heartLikeAnim
                            : DesignerArt.heartUnlikeAnim,
                        scale: 3,
                        loop: false,
                        onDone: () =>
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _playLike = false);
                        }),
                      )
                    : PixelSprite(
                        _liked
                            ? DesignerArt.heartLiked
                            : DesignerArt.heartUnliked,
                        scale: 3,
                      ),
              ),
              SizedBox(width: grid.px(4)),
              const PixelAnimation(DesignerArt.juanIdle, scale: 3),
            ],
          ),
          SizedBox(height: grid.px(3)),
          Text('ANIMATIONS', style: PixelType.body(context)),
          Wrap(
            children: [
              for (final entry in animations)
                cell(
                  entry.key,
                  PixelAnimation(entry.value as PixelFrames, scale: 3),
                ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text('ICONS', style: PixelType.body(context)),
          Wrap(
            children: [
              for (final entry in stills)
                cell(
                  entry.key,
                  PixelSprite(entry.value as PixelArt, scale: 3),
                ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(
            'ART PIXEL ${_sizeLabel(settings.artPx)} · SPRITES KEEP THEIR OWN PIXEL SIZE.',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ],
      ),
    );
  }

  /// First-run tutorial (owner's pick 2026-11-04).
  Widget _tutorials(BuildContext context, PixelGrid grid) {
    return _section(
      context,
      'First-run tutorial',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Plays the 4 lines over a pretend Home screen. '
            'Tap to finish a line, tap again for the next.',
            style: PixelType.body(context),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            key: const ValueKey('lab-tutorial'),
            label: 'Play tutorial',
            expand: true,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TutorialPreviewScreen())),
          ),
        ],
      ),
    );
  }

  Widget _celebrations(BuildContext context, PixelGrid grid) {
    return _section(
      context,
      'Celebrations',
      Column(
        children: [
          PixelButton(
            label: 'Quest complete',
            variant: PixelButtonVariant.primary,
            expand: true,
            onPressed: () => showCelebration(
              context,
              const QuestComplete(
                questTitle: 'Hundred Islands Eco Run',
                reward: 75,
              ),
            ),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            label: 'Level up (7 → 8)',
            variant: PixelButtonVariant.primary,
            expand: true,
            onPressed: () => showCelebration(
              context,
              const LevelUp(
                fromLevel: 7,
                toLevel: 8,
              ),
            ),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            label: 'Stamp earned',
            variant: PixelButtonVariant.primary,
            expand: true,
            onPressed: () => showCelebration(
              context,
              const StampEarned(
                stampName: 'JuanChoice Voter',
                stamp: DesignerArt.juanChoice,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
