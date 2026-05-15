import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/shared/presentation/widgets/app_search_field.dart';

enum AppScaffoldVariant { standard, pos, plain }

class AppScaffoldSearchConfig {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onScanPressed;
  final VoidCallback? onFilterPressed;
  final String? clearTooltip;
  final String? scanTooltip;
  final String? filterTooltip;
  final AppSearchFieldMode mode;
  final double? maxWidth;

  const AppScaffoldSearchConfig({
    this.controller,
    this.focusNode,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onScanPressed,
    this.onFilterPressed,
    this.clearTooltip,
    this.scanTooltip,
    this.filterTooltip,
    this.mode = AppSearchFieldMode.header,
    this.maxWidth,
  });

  Widget buildField({double? maxWidth}) {
    return AppSearchField(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onClear: onClear,
      onScanPressed: onScanPressed,
      onFilterPressed: onFilterPressed,
      clearTooltip: clearTooltip,
      scanTooltip: scanTooltip,
      filterTooltip: filterTooltip,
      mode: mode,
      style: AppSearchFieldStyle.onHeader,
      maxWidth: maxWidth ?? this.maxWidth,
    );
  }
}

class AppScaffold extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final IconData? icon;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final List<Widget>? compactActions;
  final AppScaffoldSearchConfig? search;
  final Widget? bottom;
  final Color backgroundColor;
  final double? maxContentWidth;
  final AppScaffoldVariant variant;

  const AppScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.icon,
    required this.body,
    this.onBack,
    this.actions = const [],
    this.compactActions,
    this.search,
    this.bottom,
    this.backgroundColor = AppColors.background,
    this.maxContentWidth,
    this.variant = AppScaffoldVariant.standard,
  }) : assert(title != null || titleWidget != null);

  static Widget header(
    BuildContext context, {
    String? title,
    String? subtitle,
    Widget? titleWidget,
    IconData? icon,
    VoidCallback? onBack,
    List<Widget> actions = const [],
    List<Widget>? compactActions,
    AppScaffoldSearchConfig? search,
    Widget? bottom,
    AppScaffoldVariant variant = AppScaffoldVariant.standard,
  }) {
    return _AppScaffoldHeader(
      title: title,
      subtitle: subtitle,
      titleWidget: titleWidget,
      icon: icon,
      onBack: onBack,
      actions: actions,
      compactActions: compactActions,
      search: search,
      bottom: bottom,
      variant: variant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = maxContentWidth == null
        ? body
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth!),
              child: body,
            ),
          );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _AppScaffoldHeader(
            title: title,
            subtitle: subtitle,
            titleWidget: titleWidget,
            icon: icon,
            onBack: onBack,
            actions: actions,
            compactActions: compactActions,
            search: search,
            bottom: bottom,
            variant: variant,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _AppScaffoldHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final IconData? icon;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final List<Widget>? compactActions;
  final AppScaffoldSearchConfig? search;
  final Widget? bottom;
  final AppScaffoldVariant variant;

  const _AppScaffoldHeader({
    this.title,
    this.subtitle,
    this.titleWidget,
    this.icon,
    this.onBack,
    this.actions = const [],
    this.compactActions,
    this.search,
    this.bottom,
    this.variant = AppScaffoldVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.medium;
        final horizontalPadding = variant == AppScaffoldVariant.pos
            ? AppSpacing.lg
            : AppSpacing.md;
        final activeActions = compact ? compactActions ?? actions : actions;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.sm,
                horizontalPadding,
                search != null || bottom != null
                    ? AppSpacing.lg
                    : AppSpacing.sm,
              ),
              child: compact
                  ? _buildCompact(activeActions)
                  : _buildWide(activeActions),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompact(List<Widget> activeActions) {
    return Column(
      children: [
        Row(
          children: [
            ..._leading(),
            Expanded(child: _title()),
            if (activeActions.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              _actions(activeActions),
            ],
          ],
        ),
        if (search != null) ...[
          const SizedBox(height: AppSpacing.sm),
          search!.buildField(maxWidth: double.infinity),
        ],
        if (bottom != null) ...[const SizedBox(height: AppSpacing.md), bottom!],
      ],
    );
  }

  Widget _buildWide(List<Widget> activeActions) {
    return Row(
      children: [
        ..._leading(),
        if (search == null)
          Expanded(child: _title())
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: _title(),
          ),
        if (search != null) ...[
          const SizedBox(width: AppSpacing.xxl),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: search!.buildField(),
            ),
          ),
        ] else
          const Spacer(),
        if (bottom != null) ...[
          const SizedBox(width: AppSpacing.md),
          Flexible(child: bottom!),
        ],
        if (activeActions.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.md),
          _actions(activeActions),
        ],
      ],
    );
  }

  List<Widget> _leading() {
    return [
      if (onBack != null) ...[
        IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onPrimary),
          onPressed: onBack,
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
      if (icon != null) ...[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.onPrimary, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
      ],
    ];
  }

  Widget _title() {
    if (titleWidget != null) return titleWidget!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.onPrimary.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _actions(List<Widget> items) {
    return IconTheme(
      data: const IconThemeData(color: AppColors.onPrimary),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppColors.onPrimary),
        child: Row(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}
