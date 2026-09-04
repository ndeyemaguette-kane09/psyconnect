import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.md,
    this.color = AppColors.white,
    this.borderColor,
    this.shadow,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color? borderColor;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: AppColors.tealLight,
          highlightColor: AppColors.tealSoft,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class AppNoticeCard extends StatelessWidget {
  const AppNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.accent = AppColors.gold,
    this.background = AppColors.goldLight,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color accent;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          message!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 6, top: 2),
                    child:
                        Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppHero extends StatelessWidget {
  const AppHero({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 22),
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.teal,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  static const TextStyle _label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _label,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Divider(height: 1, thickness: 1),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      actionLabel!.toUpperCase(),
                      style: _label.copyWith(color: AppColors.teal),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.accent = AppColors.teal,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: accent),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Connexion impossible',
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.wifi_off_rounded,
      title: title,
      message: message,
      accent: AppColors.danger,
      actionLabel: onRetry == null ? null : 'Réessayer',
      onAction: onRetry,
    );
  }
}

class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.tealDark,
    this.background = AppColors.tealLight,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: dense ? 13 : 15, color: color)
        else
          Container(
            width: dense ? 6 : 7,
            height: dense ? 6 : 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        SizedBox(width: dense ? 5 : 7),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: dense ? 11 : 12,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.teal,
    this.size = 42,
    this.background,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(icon, color: color, size: size * 0.58),
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.color = AppColors.teal,
    this.showRing = true,
  });

  final String name;
  final double size;
  final Color color;
  final bool showRing;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.first.substring(0, 1);
    final last = parts.last.substring(0, 1);
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.10),
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: size * 0.36,
              color: color,
              height: 1,
            ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = AppColors.teal,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(color: AppColors.text, height: 1),
            ),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                height: 1.3,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.color = AppColors.teal,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  final Color color;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            isLabelVisible: badgeCount > 0,
            label: Text('$badgeCount'),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              height: 1.2,
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 3),
            Text(
              sublabel!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.muted,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FadeInUp extends StatefulWidget {
  const FadeInUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  late final Animation<double> _curved = CurvedAnimation(
    parent: _ctrl,
    curve: AppMotion.emphasized,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) => Opacity(
        opacity: _curved.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class StatBand extends StatelessWidget {
  const StatBand({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final row = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      row.add(Expanded(child: children[i]));
      if (i != children.length - 1) {
        row.add(Container(width: 1, color: AppColors.border));
      }
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderStrong),
          bottom: BorderSide(color: AppColors.borderStrong),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: row),
      ),
    );
  }
}

class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor = AppColors.teal,
    this.onTap,
    this.showTopBorder = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: showTopBorder
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
          bottom: const BorderSide(color: AppColors.border),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 21),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ??
                    const Icon(Icons.chevron_right,
                        color: AppColors.faint, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
