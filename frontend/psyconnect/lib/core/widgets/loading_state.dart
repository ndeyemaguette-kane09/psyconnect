import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// État de chargement commun : explicite, accessible et aligné sur la charte.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.label = 'Chargement en cours…',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.teal,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Aperçu de liste pendant le chargement, afin d'éviter un écran visuellement vide.
class AppListSkeleton extends StatefulWidget {
  const AppListSkeleton({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 104,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  @override
  State<AppListSkeleton> createState() => _AppListSkeletonState();
}

class _AppListSkeletonState extends State<AppListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement du contenu',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final shade = Color.lerp(
            AppColors.tealLight,
            AppColors.white,
            _controller.value,
          )!;
          return ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: widget.padding,
            itemCount: widget.itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => _SkeletonCard(
              height: widget.itemHeight,
              color: shade,
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Bar(width: double.infinity, color: color),
                const SizedBox(height: 10),
                _Bar(width: 140, color: color),
                const SizedBox(height: 8),
                _Bar(width: 92, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 9,
        decoration: BoxDecoration(
          color: color,
        ),
      );
}
