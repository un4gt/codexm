import 'package:flutter/material.dart';

enum AdaptiveWidthClass { compact, medium, expanded }

class AdaptiveBreakpoints {
  const AdaptiveBreakpoints._();

  static const double compactMaxWidth = 600;
  static const double mediumMaxWidth = 840;
  static const EdgeInsets compactPagePadding = EdgeInsets.fromLTRB(16, 16, 16, 20);
  static const EdgeInsets mediumPagePadding = EdgeInsets.fromLTRB(24, 20, 24, 24);
  static const EdgeInsets expandedPagePadding = EdgeInsets.fromLTRB(32, 24, 32, 28);
  static const EdgeInsets compactHeaderPadding = EdgeInsets.all(20);
  static const EdgeInsets mediumHeaderPadding = EdgeInsets.all(24);
  static const EdgeInsets expandedHeaderPadding = EdgeInsets.all(28);

  static AdaptiveWidthClass resolve(double width) {
    if (width < compactMaxWidth) {
      return AdaptiveWidthClass.compact;
    }
    if (width < mediumMaxWidth) {
      return AdaptiveWidthClass.medium;
    }
    return AdaptiveWidthClass.expanded;
  }

  static EdgeInsets resolvePagePadding(AdaptiveWidthClass widthClass) {
    switch (widthClass) {
      case AdaptiveWidthClass.compact:
        return compactPagePadding;
      case AdaptiveWidthClass.medium:
        return mediumPagePadding;
      case AdaptiveWidthClass.expanded:
        return expandedPagePadding;
    }
  }

  static EdgeInsets resolveHeaderPadding(AdaptiveWidthClass widthClass) {
    switch (widthClass) {
      case AdaptiveWidthClass.compact:
        return compactHeaderPadding;
      case AdaptiveWidthClass.medium:
        return mediumHeaderPadding;
      case AdaptiveWidthClass.expanded:
        return expandedHeaderPadding;
    }
  }
}

extension AdaptiveWidthClassX on AdaptiveWidthClass {
  bool get isCompact => this == AdaptiveWidthClass.compact;
  bool get isMedium => this == AdaptiveWidthClass.medium;
  bool get isExpanded => this == AdaptiveWidthClass.expanded;
}

extension AdaptiveBreakpointContextX on BuildContext {
  AdaptiveWidthClass adaptiveWidthClassOf(double width) {
    return AdaptiveBreakpoints.resolve(width);
  }

  AdaptiveWidthClass get adaptiveWidthClass {
    return AdaptiveBreakpoints.resolve(MediaQuery.sizeOf(this).width);
  }

  EdgeInsets get adaptivePagePadding {
    return AdaptiveBreakpoints.resolvePagePadding(adaptiveWidthClass);
  }

  EdgeInsets get adaptiveHeaderPadding {
    return AdaptiveBreakpoints.resolveHeaderPadding(adaptiveWidthClass);
  }
}
