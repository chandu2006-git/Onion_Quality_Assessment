import 'package:flutter/material.dart';

/// Lays cards out in a responsive grid without ever overflowing horizontally.
///
/// Columns are derived from the available width, so the same widget behaves
/// correctly on a phone, a tablet and a wide desktop display.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.minCardWidth = 260,
    this.spacing = 16,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minCardWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = ((width + spacing) / (minCardWidth + spacing)).floor();
        columns = columns.clamp(1, maxColumns);
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: cardWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

/// Centred content column with consistent page gutters.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 1280,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? 20.0 : (width < 1000 ? 32.0 : 48.0);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(horizontal: horizontal, vertical: 32),
          child: child,
        ),
      ),
    );
  }
}
