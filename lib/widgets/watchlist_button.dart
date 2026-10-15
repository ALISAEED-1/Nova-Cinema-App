import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../features/watchlist/watchlist_controller.dart';
import '../models/movie.dart';
import 'app_snackbar.dart';

/// Add/remove-from-watchlist control with a bounce on toggle.
///
/// Renders as a full-width secondary button by default or a compact circular
/// icon when [compact] is true.
class WatchlistButton extends StatefulWidget {
  const WatchlistButton({
    super.key,
    required this.movie,
    this.compact = false,
    this.light = false,
  });

  final Movie movie;
  final bool compact;

  /// Use on dark artwork where a translucent fill reads better.
  final bool light;

  @override
  State<WatchlistButton> createState() => _WatchlistButtonState();
}

class _WatchlistButtonState extends State<WatchlistButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.25), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1), weight: 60),
  ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    _bounce.forward(from: 0);
    final added = await context.read<WatchlistController>().toggle(widget.movie);
    if (!mounted) return;
    showAppSnackBar(
      context,
      added ? 'Added to My List' : 'Removed from My List',
      icon: added ? Icons.check_rounded : Icons.remove_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = context.select<WatchlistController, bool>(
      (w) => w.contains(widget.movie.id),
    );

    final icon = ScaleTransition(
      scale: _scale,
      child: AnimatedSwitcher(
        duration: AppDurations.fast,
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          saved ? Icons.check_rounded : Icons.add_rounded,
          key: ValueKey(saved),
          size: widget.compact ? 24 : 22,
        ),
      ),
    );

    if (widget.compact) {
      return Material(
        color: saved ? AppColors.primary : AppColors.overlay,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: saved ? 'Remove from My List' : 'Add to My List',
          onPressed: _toggle,
          color: Colors.white,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          icon: icon,
        ),
      );
    }

    return FilledButton.tonal(
      onPressed: _toggle,
      style: FilledButton.styleFrom(
        backgroundColor:
            saved ? AppColors.primary : const Color(0x33FFFFFF),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        textStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              saved ? 'In My List' : 'My List',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
