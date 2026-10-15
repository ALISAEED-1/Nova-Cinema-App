import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';

/// Overlay controls for [PlayerScreen]. Purely presentational — every
/// interaction is reported through callbacks.
class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.visible,
    required this.title,
    required this.value,
    required this.duration,
    required this.position,
    required this.completed,
    required this.scrubPosition,
    required this.landscape,
    required this.onBack,
    required this.onTogglePlay,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.onToggleOrientation,
    required this.onInteraction,
  });

  final bool visible;
  final String title;
  final VideoPlayerValue value;

  /// Authoritative duration -- falls back to catalogue metadata when the
  /// container misreports it, so the scrubber still works.
  final Duration duration;

  /// Playback position -- supplied by the screen so sources that never report
  /// one can still drive the scrubber from a virtual clock.
  final Duration position;

  /// True only when playback really finished -- never from a misreported
  /// duration, so pausing shows play rather than replay.
  final bool completed;
  final Duration? scrubPosition;
  final bool landscape;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final ValueChanged<Duration> onScrubStart;
  final ValueChanged<Duration> onScrubUpdate;
  final ValueChanged<Duration> onScrubEnd;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleOrientation;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    final pos = scrubPosition ?? position;
    final maxMs = duration.inMilliseconds.toDouble();
    final positionMs = pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
    final compact = MediaQuery.sizeOf(context).height < 420;
    // Fragmented MP4s report a duration of a few milliseconds, which would draw
    // a permanently full scrubber and a "-00:00" countdown. There is nothing
    // real to scrub in that case, so the whole progress row is left out.
    final hasTimeline = duration.inMilliseconds > 1000;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppDurations.normal,
        child: Listener(
          onPointerDown: (_) => onInteraction(),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC000000),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xD9000000),
                ],
                stops: [0, 0.28, 0.65, 1],
              ),
            ),
            child: Stack(
              children: [
                // Centred on the player itself rather than on the gap between
                // the top and bottom chrome, so it lands on the true middle.
                Center(
                  child: _CenterControls(
                    value: value,
                    completed: completed,
                    compact: compact,
                    onTogglePlay: onTogglePlay,
                    onSkipBack: onSkipBack,
                    onSkipForward: onSkipForward,
                  ),
                ),
                // Vertical volume against the left edge, as on the web player.
                Positioned.fill(
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _VolumeColumn(
                        volume: value.volume,
                        compact: compact,
                        onChanged: onVolumeChanged,
                        onToggleMute: onToggleMute,
                      ),
                    ),
                  ),
                ),
                SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: compact ? AppSpacing.xs : AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    _TopBar(title: title, onBack: onBack),
                    const Spacer(),
                    _SeekBar(
                      positionMs: hasTimeline ? positionMs : 0,
                      maxMs: hasTimeline ? maxMs : 0,
                      buffered: value.buffered,
                      onScrubStart: (ms) =>
                          onScrubStart(Duration(milliseconds: ms.round())),
                      onScrubUpdate: (ms) =>
                          onScrubUpdate(Duration(milliseconds: ms.round())),
                      onScrubEnd: (ms) =>
                          onScrubEnd(Duration(milliseconds: ms.round())),
                    ),
                    Row(
                      children: [
                        Text(
                          hasTimeline ? Formatters.duration(pos) : '--:--',
                          style: _timeStyle,
                        ),
                        const Spacer(),
                        Text(
                          hasTimeline
                              ? Formatters.remaining(pos, duration)
                              : '--:--',
                          style: _timeStyle,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
                    _BottomBar(
                      landscape: landscape,
                      onToggleOrientation: onToggleOrientation,
                    ),
                  ],
                ),
              ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const TextStyle _timeStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          color: AppColors.textPrimary,
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _CenterControls extends StatelessWidget {
  const _CenterControls({
    required this.value,
    required this.completed,
    required this.compact,
    required this.onTogglePlay,
    required this.onSkipBack,
    required this.onSkipForward,
  });

  final VideoPlayerValue value;
  final bool completed;
  final bool compact;
  final VoidCallback onTogglePlay;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;

  @override
  Widget build(BuildContext context) {
    // Playing wins over "completed": a source that misreports its duration is
    // still playing, and must show a pause button rather than replay.
    final IconData playIcon;
    if (value.isPlaying) {
      playIcon = Icons.pause_rounded;
    } else if (completed) {
      playIcon = Icons.replay_rounded;
    } else {
      playIcon = Icons.play_arrow_rounded;
    }
    final gap = compact ? AppSpacing.xxl : 56.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SkipButton(
          icon: Icons.replay_10_rounded,
          label: 'Back 10 seconds',
          onPressed: onSkipBack,
          size: compact ? 36 : 44,
        ),
        SizedBox(width: gap),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: value.isPlaying ? 'Pause' : 'Play',
            onPressed: onTogglePlay,
            iconSize: compact ? 40 : 52,
            color: AppColors.textOnLight,
            constraints: BoxConstraints.tightFor(
              width: compact ? 64 : 84,
              height: compact ? 64 : 84,
            ),
            icon: AnimatedSwitcher(
              duration: AppDurations.fast,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(playIcon, key: ValueKey(playIcon)),
            ),
          ),
        ),
        SizedBox(width: gap),
        _SkipButton(
          icon: Icons.forward_10_rounded,
          label: 'Forward 10 seconds',
          onPressed: onSkipForward,
          size: compact ? 36 : 44,
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.size,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      iconSize: size,
      color: AppColors.textPrimary,
      icon: Icon(icon),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.positionMs,
    required this.maxMs,
    required this.buffered,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
  });

  final double positionMs;
  final double maxMs;
  final List<DurationRange> buffered;
  final ValueChanged<double> onScrubStart;
  final ValueChanged<double> onScrubUpdate;
  final ValueChanged<double> onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final bufferedEnd = buffered.isEmpty
        ? 0.0
        : buffered
            .map((r) => r.end.inMilliseconds.toDouble())
            .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (maxMs > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (bufferedEnd / maxMs).clamp(0, 1),
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                  color: const Color(0x4DFFFFFF),
                ),
              ),
            ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              inactiveTrackColor: const Color(0x33FFFFFF),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: maxMs > 0 ? positionMs.clamp(0, maxMs) : 0,
              max: maxMs > 0 ? maxMs : 1,
              onChangeStart: maxMs > 0 ? onScrubStart : null,
              onChanged: maxMs > 0 ? onScrubUpdate : null,
              onChangeEnd: maxMs > 0 ? onScrubEnd : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical volume slider with the mute toggle beneath it, sitting against the
/// left edge of the video — the arrangement the web player used.
class _VolumeColumn extends StatelessWidget {
  const _VolumeColumn({
    required this.volume,
    required this.compact,
    required this.onChanged,
    required this.onToggleMute,
  });

  final double volume;
  final bool compact;
  final ValueChanged<double> onChanged;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final IconData volumeIcon;
    if (volume == 0) {
      volumeIcon = Icons.volume_off_rounded;
    } else if (volume < 0.5) {
      volumeIcon = Icons.volume_down_rounded;
    } else {
      volumeIcon = Icons.volume_up_rounded;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rotated so the track runs bottom (silent) to top (loud). Both
        // dimensions are pinned: a Slider grows to any bounded height it is
        // given, and RotatedBox swaps the axes, so an unpinned height would
        // make the control as thick as the screen is wide.
        RotatedBox(
          quarterTurns: 3,
          child: SizedBox(
            width: compact ? 96 : 140,
            height: 44,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: Colors.white,
                thumbColor: Colors.white,
                inactiveTrackColor: const Color(0x33FFFFFF),
                overlayColor: const Color(0x22FFFFFF),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(value: volume, onChanged: onChanged),
            ),
          ),
        ),
        IconButton(
          tooltip: volume == 0 ? 'Unmute' : 'Mute',
          onPressed: onToggleMute,
          color: AppColors.textPrimary,
          icon: Icon(volumeIcon),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.landscape,
    required this.onToggleOrientation,
  });

  final bool landscape;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        TextButton.icon(
          onPressed: onToggleOrientation,
          style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
          icon: Icon(
            landscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
          ),
          label: Text(landscape ? 'Exit fullscreen' : 'Fullscreen'),
        ),
      ],
    );
  }
}
