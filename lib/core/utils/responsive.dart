import 'package:flutter/widgets.dart';

/// Breakpoint helpers so layouts adapt from small phones to tablets.
class Responsive {
  Responsive._(this.size, this.padding);

  factory Responsive.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Responsive._(mq.size, mq.padding);
  }

  final Size size;
  final EdgeInsets padding;

  double get width => size.width;
  double get height => size.height;
  bool get isLandscape => width > height;

  bool get isCompact => size.shortestSide < 360;
  bool get isTablet => size.shortestSide >= 600;
  bool get isLargeTablet => size.shortestSide >= 840;

  /// Number of columns for poster grids.
  int get gridColumns {
    if (isLargeTablet) return isLandscape ? 5 : 4;
    if (isTablet) return isLandscape ? 4 : 3;
    return 2;
  }

  /// Width of a horizontally-scrolling landscape card.
  double get cardWidth {
    if (isTablet) return 220;
    if (isCompact) return 150;
    return 168;
  }

  double get largeCardWidth => isTablet ? 320 : 250;

  /// Hero height as a fraction of the viewport, clamped for sanity.
  double get heroHeight {
    final h = isTablet ? height * 0.62 : height * 0.68;
    return h.clamp(420, 700);
  }

  /// Max content width on very wide screens keeps text readable.
  double get contentMaxWidth => 1100;
}
