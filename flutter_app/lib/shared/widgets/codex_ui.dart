import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

enum CodexStatusTone { neutral, success, warning, error, info, running }

class CodexCard extends StatelessWidget {
  const CodexCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.selected = false,
    this.elevated = false,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool selected;
  final bool elevated;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.codexColors;
    final radius = borderRadius ?? CodexMRadii.lg;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: borderColor ?? (selected ? colors.primaryMuted : colors.border),
      ),
    );
    final card = Material(
      color:
          backgroundColor ?? (selected ? colors.primarySoft : colors.surface),
      elevation: elevated ? 8 : 0,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.12),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(CodexMSpacing.md),
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return Material(
        color:
            backgroundColor ?? (selected ? colors.primarySoft : colors.surface),
        elevation: elevated ? 8 : 0,
        shadowColor: Theme.of(
          context,
        ).colorScheme.shadow.withValues(alpha: 0.12),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(CodexMSpacing.md),
          child: child,
        ),
      );
    }
    return card;
  }
}

class CodexStatusChip extends StatelessWidget {
  const CodexStatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.compact = false,
  });

  final String label;
  final CodexStatusTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = _statusSpec(context, tone, icon);
    final minHeight = compact ? 28.0 : 32.0;
    final iconSize = compact ? 14.0 : 16.0;

    return Semantics(
      label: label,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: BorderRadius.circular(CodexMRadii.pill),
          border: Border.all(color: spec.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tone == CodexStatusTone.running)
              SizedBox(
                key: const ValueKey('codex-status-running-spinner'),
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: spec.foreground,
                ),
              )
            else
              Icon(spec.icon, size: iconSize, color: spec.foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: spec.foreground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _CodexStatusSpec _statusSpec(
    BuildContext context,
    CodexStatusTone tone,
    IconData? icon,
  ) {
    final colors = context.codexColors;
    switch (tone) {
      case CodexStatusTone.success:
        return _CodexStatusSpec(
          background: colors.successSoft,
          border: colors.success.withValues(alpha: 0.22),
          foreground: colors.success,
          icon: icon ?? Icons.check_circle_outline,
        );
      case CodexStatusTone.warning:
        return _CodexStatusSpec(
          background: colors.warningSoft,
          border: colors.warning.withValues(alpha: 0.22),
          foreground: colors.warning,
          icon: icon ?? Icons.pending_actions_outlined,
        );
      case CodexStatusTone.error:
        return _CodexStatusSpec(
          background: colors.errorSoft,
          border: colors.error.withValues(alpha: 0.22),
          foreground: colors.error,
          icon: icon ?? Icons.error_outline,
        );
      case CodexStatusTone.info:
        return _CodexStatusSpec(
          background: colors.infoSoft,
          border: colors.info.withValues(alpha: 0.22),
          foreground: colors.info,
          icon: icon ?? Icons.info_outline,
        );
      case CodexStatusTone.running:
        return _CodexStatusSpec(
          background: colors.infoSoft,
          border: colors.info.withValues(alpha: 0.24),
          foreground: colors.info,
          icon: icon ?? Icons.sync,
        );
      case CodexStatusTone.neutral:
        return _CodexStatusSpec(
          background: colors.surfaceMuted,
          border: colors.border,
          foreground: colors.textMuted,
          icon: icon ?? Icons.circle_outlined,
        );
    }
  }
}

class CodexIconButton extends StatelessWidget {
  const CodexIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.primary = false,
    this.size = 40,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool primary;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.codexColors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: SizedBox.square(
        dimension: size < 48 ? 48 : size,
        child: Center(
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: icon,
            style: IconButton.styleFrom(
              minimumSize: Size.square(size),
              fixedSize: Size.square(size),
              padding: EdgeInsets.zero,
              backgroundColor: primary ? colors.primary : colors.primarySoft,
              foregroundColor: primary ? Colors.white : colors.primary,
              disabledBackgroundColor: colors.surfaceMuted,
              disabledForegroundColor: colors.textSubtle,
            ),
          ),
        ),
      ),
    );
  }
}

class CodexSectionHeader extends StatelessWidget {
  const CodexSectionHeader({super.key, required this.title, this.trailing});

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
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class CodexEmptyState extends StatelessWidget {
  const CodexEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;
    return CodexCard(
      backgroundColor: colors.surfaceMuted,
      borderColor: colors.divider,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(CodexMRadii.md),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          const SizedBox(width: CodexMSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: CodexMSpacing.xxs),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    height: 1.45,
                  ),
                ),
                if (action case final action?) ...[
                  const SizedBox(height: CodexMSpacing.sm),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CodexCodeBlock extends StatelessWidget {
  const CodexCodeBlock({
    super.key,
    required this.content,
    this.header,
    this.maxHeight,
    this.copyTooltip,
    this.copiedLabel,
  });

  final String content;
  final Widget? header;
  final double? maxHeight;
  final String? copyTooltip;
  final String? copiedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;
    final l10n = AppLocalizations.of(context);
    final code = content.trimRight();
    final effectiveCopyTooltip = copyTooltip ?? l10n.commonCopy;
    final effectiveCopiedLabel = copiedLabel ?? l10n.commonCopiedToClipboard;

    return Container(
      decoration: BoxDecoration(
        color: colors.codeBg,
        borderRadius: BorderRadius.circular(CodexMRadii.md),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
              child: Row(
                children: [
                  Expanded(child: header!),
                  _CopyButton(
                    content: code,
                    tooltip: effectiveCopyTooltip,
                    copiedLabel: effectiveCopiedLabel,
                  ),
                ],
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: _CopyButton(
                  content: code,
                  tooltip: effectiveCopyTooltip,
                  copiedLabel: effectiveCopiedLabel,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight ?? double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectionArea(
                  child: SelectableText(
                    code,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.codeFg,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.42,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.content,
    required this.tooltip,
    required this.copiedLabel,
  });

  final String content;
  final String tooltip;
  final String copiedLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: content.isEmpty
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(copiedLabel)));
              },
        icon: const Icon(Icons.copy_all_outlined, size: 18),
      ),
    );
  }
}

class _CodexStatusSpec {
  const _CodexStatusSpec({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}
