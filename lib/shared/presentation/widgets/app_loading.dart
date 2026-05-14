import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';

/// A unified loading indicator enforcing SSOT for loading states.
///
/// Uses a pulsing animation wrapper around [CircularProgressIndicator]
/// for a premium feel across all loading contexts.
class AppLoading extends StatefulWidget {
  final bool centered;
  final double size;
  final Color? color;
  final double strokeWidth;

  const AppLoading({
    super.key,
    this.centered = true,
    this.size = 32.0,
    this.color,
    this.strokeWidth = 3.0,
  });

  /// A smaller variant suitable for inline elements or buttons.
  const AppLoading.small({
    super.key,
    this.centered = true,
    this.size = 16.0,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  State<AppLoading> createState() => _AppLoadingState();
}

class _AppLoadingState extends State<AppLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicator = FadeTransition(
      opacity: _pulseAnimation,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: widget.strokeWidth,
          strokeCap: StrokeCap.round,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.color ?? AppColors.primary,
          ),
        ),
      ),
    );

    if (widget.centered) {
      return Center(child: indicator);
    }
    return indicator;
  }
}

/// A full-screen loading overlay with a branded backdrop.
///
/// Use this for major state transitions (initial load, setup, sync).
class AppLoadingOverlay extends StatelessWidget {
  final String? message;

  const AppLoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: AppSpacing.paddingXxl,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.borderRadiusXl,
              boxShadow: AppSpacing.shadowLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLoading(centered: false, size: 44, strokeWidth: 3.5),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
