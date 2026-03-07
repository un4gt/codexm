import 'package:codexm_flutter/shared/widgets/adaptive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses official Google width breakpoints for phone and tablet', () {
    expect(
      AdaptiveBreakpoints.resolve(599),
      AdaptiveWidthClass.compact,
    );
    expect(
      AdaptiveBreakpoints.resolve(600),
      AdaptiveWidthClass.medium,
    );
    expect(
      AdaptiveBreakpoints.resolve(839),
      AdaptiveWidthClass.medium,
    );
    expect(
      AdaptiveBreakpoints.resolve(840),
      AdaptiveWidthClass.expanded,
    );
  });

  test('resolves graded page and header padding for each width class', () {
    expect(
      AdaptiveBreakpoints.resolvePagePadding(AdaptiveWidthClass.compact),
      const EdgeInsets.fromLTRB(16, 16, 16, 20),
    );
    expect(
      AdaptiveBreakpoints.resolvePagePadding(AdaptiveWidthClass.medium),
      const EdgeInsets.fromLTRB(24, 20, 24, 24),
    );
    expect(
      AdaptiveBreakpoints.resolvePagePadding(AdaptiveWidthClass.expanded),
      const EdgeInsets.fromLTRB(32, 24, 32, 28),
    );
    expect(
      AdaptiveBreakpoints.resolveHeaderPadding(AdaptiveWidthClass.compact),
      const EdgeInsets.all(20),
    );
    expect(
      AdaptiveBreakpoints.resolveHeaderPadding(AdaptiveWidthClass.medium),
      const EdgeInsets.all(24),
    );
    expect(
      AdaptiveBreakpoints.resolveHeaderPadding(AdaptiveWidthClass.expanded),
      const EdgeInsets.all(28),
    );
  });
}
