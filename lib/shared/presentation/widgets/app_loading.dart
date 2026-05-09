import 'package:flutter/material.dart';
import 'package:pos_flutter/core/design_system/colors.dart';

/// A unified loading indicator enforcing SSOT for loading states.
class AppLoading extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? AppColors.primary),
      ),
    );

    if (centered) {
      return Center(child: indicator);
    }
    return indicator;
  }
}
