import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'connection_banner.dart';

/// Standard layout container for JuanderQuest screens.
///
/// Features safe areas, warm background, responsive horizontal gutters,
/// maximum content width capping (768px for tablet/desktop), and optional app bar.
class JdqScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color backgroundColor;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  const JdqScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor = AppColors.background,
    this.scrollable = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.gutter);

    Widget content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 768),
        child: padding != null
            ? Padding(padding: effectivePadding, child: body)
            : body,
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding == null ? effectivePadding : EdgeInsets.zero,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: SafeArea(
        child: Column(
          children: [
            _bannerFor(context),
            Expanded(child: content),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }

  /// Render the connectivity banner only where a ProviderScope exists so
  /// isolated widget tests and previews keep working without one.
  Widget _bannerFor(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
      return const ConnectionBanner();
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
