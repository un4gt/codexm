import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'adaptive_breakpoints.dart';
import 'codex_ui.dart';

class StitchPageScaffold extends StatelessWidget {
  const StitchPageScaffold({
    super.key,
    required this.pageTitle,
    this.brandTitle = 'CodexM',
    this.brandIcon,
    this.topActions = const <Widget>[],
    this.kickerText,
    this.children = const <Widget>[],
    this.floatingActionButton,
  });

  final String pageTitle;
  final String brandTitle;
  final IconData? brandIcon;
  final List<Widget> topActions;
  final String? kickerText;
  final List<Widget> children;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.codexColors;
    final tokens = context.appTokens;
    final padding = context.adaptivePagePadding;

    return Scaffold(
      backgroundColor: colors.pageBg,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tokens.maxContentWidth),
            child: ListView(
              padding: padding,
              children: [
                StitchTopBar(
                  title: brandTitle,
                  icon: brandIcon,
                  actions: topActions,
                ),
                const SizedBox(height: 14),
                StitchHeroTitle(title: pageTitle, kickerText: kickerText),
                const SizedBox(height: 16),
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index < children.length - 1)
                    SizedBox(height: tokens.sectionSpacing),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StitchTopBar extends StatelessWidget {
  const StitchTopBar({
    super.key,
    required this.title,
    this.icon,
    this.actions = const <Widget>[],
  });

  final String title;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;
    final leadingIcon = icon;

    return Row(
      children: [
        if (leadingIcon != null)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(CodexMRadii.md),
            ),
            child: Icon(leadingIcon, color: colors.primary),
          ),
        if (leadingIcon != null) const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: colors.textStrong,
            ),
          ),
        ),
        for (final action in actions) ...[const SizedBox(width: 8), action],
      ],
    );
  }
}

class StitchHeroTitle extends StatelessWidget {
  const StitchHeroTitle({super.key, required this.title, this.kickerText});

  final String title;
  final String? kickerText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 34,
            letterSpacing: 0,
            color: colors.textStrong,
          ),
        ),
        if (kickerText?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            kickerText!.trim(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textMuted,
              letterSpacing: 0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class StitchSectionHeader extends StatelessWidget {
  const StitchSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;

    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        ...[trailing].whereType<Widget>(),
      ],
    );
  }
}

class StitchInfoBanner extends StatelessWidget {
  const StitchInfoBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;

    return CodexCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      backgroundColor: colors.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (subtitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
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

class StitchListItem extends StatelessWidget {
  const StitchListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;

    return CodexCard(
      onTap: onTap,
      selected: highlighted,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      backgroundColor: highlighted ? colors.primarySoft : colors.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Padding(padding: const EdgeInsets.only(top: 2), child: leading!),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                if (subtitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class StitchPill extends StatelessWidget {
  const StitchPill({
    super.key,
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? colors.primarySoft : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(CodexMRadii.pill),
        border: Border.all(
          color: emphasized ? colors.primaryMuted : colors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
