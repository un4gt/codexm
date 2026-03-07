import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'adaptive_breakpoints.dart';

class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({
    super.key,
    required this.title,
    required this.description,
    this.children = const <Widget>[],
    this.appBar,
    this.headerActions = const <Widget>[],
  });

  final String title;
  final String description;
  final List<Widget> children;
  final PreferredSizeWidget? appBar;
  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final pagePadding = context.adaptivePagePadding;
    final headerPadding = context.adaptiveHeaderPadding;

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tokens.maxContentWidth),
            child: ListView(
              padding: pagePadding,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(tokens.cardRadius + 4),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Padding(
                    padding: headerPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (headerActions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: headerActions,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                for (var index = 0; index < children.length; index++) ...[
                  SizedBox(height: index == 0 ? tokens.sectionSpacing : tokens.compactSpacing),
                  children[index],
                ],
                SizedBox(height: MediaQuery.paddingOf(context).bottom + pagePadding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
