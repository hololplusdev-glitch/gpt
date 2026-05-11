import 'package:flutter/material.dart';
import 'package:holol_POS/core/design_system/layout.dart';
import 'package:holol_POS/core/design_system/spacing.dart';

/// A unified responsive row that switches to a Column on narrow screens.
/// Replaces the manual LayoutBuilder logic scattered across screens.
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final double breakpoint;
  final bool expandChildren;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.breakpoint = AppBreakpoints.compact,
    this.expandChildren = true,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: crossAxisAlignment,
            children: _withSpacing(
              children.map(_columnChild).toList(),
              vertical: true,
            ),
          );
        } else {
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisAlignment: mainAxisAlignment,
            children: _withSpacing(children.map(_rowChild).toList()),
          );
        }
      },
    );
  }

  Widget _rowChild(Widget child) {
    if (child is Flexible) return child;
    return expandChildren ? Expanded(child: child) : child;
  }

  Widget _columnChild(Widget child) {
    if (child is Flexible) return child.child;
    return child;
  }

  List<Widget> _withSpacing(List<Widget> widgets, {bool vertical = false}) {
    if (widgets.isEmpty) return const [];
    final spaced = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) {
        spaced.add(
          vertical ? SizedBox(height: spacing) : SizedBox(width: spacing),
        );
      }
      spaced.add(widgets[i]);
    }
    return spaced;
  }
}
