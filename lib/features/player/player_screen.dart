import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/movie.dart';
import '../../widgets/state_widgets.dart';
import 'playback_controller.dart';
import 'widgets/player_controls.dart';

/// Full-screen video player for a title's movie or trailer.
///
/// Ports the web player's feature set: play/pause, ±10s skip, seek, volume
/// and mute, fullscreen (orientation) toggle, auto-hiding controls, loading
/// and error states, plus resume-from-last-position for full movies.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.movie, this.trailer = false});

  final Movie movie;
  final bool trailer;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _progressSaveInterval = Duration(seconds: 5);
  static const _skipStep = Duration(seconds: 10);

  VideoPlayerController? _controller;
  late final PlaybackController _playback;

  Timer? _hideTimer;
  Timer? _saveTimer;
  bool _controlsVisible = true;
  bool _initializing = true;
  String? _error;
  bool _landscape = true;
  double _lastVolume = 1;

  /// Position while the user drags the seek bar (null when not dragging).
  Duration? _scrubPosition;

  String? get _source =>
      widget.trailer ? widget.movie.trailerAsset : widget.movie.videoAsset;

  bool get _tracksProgress => !widget.trailer;

  /// The container duration when it is believable, otherwise the runtime from
  /// the catalogue. Fragmented MP4s report a few milliseconds, which would
  /// otherwise leave the scrubber pinned full.
  /// Whether the container reports a duration we can believe. Fragmented MP4s
  /// report a few milliseconds, which makes isCompleted true the moment the
  /// video is not actively playing -- including while merely paused.
  bool get _durationIsReliable =>
      (_controller?.value.duration.inMilliseconds ?? 0) > 1000;

  /// Playback genuinely reached the end, as opposed to a misreported duration.
  bool get _isCompleted => _usesVirtualClock
      ? (_effectiveDuration > Duration.zero &&
          _virtualPosition >= _effectiveDuration)
      : (_controller?.value.isCompleted ?? false);

  Duration get _effectiveDuration {
    final reported = _controller?.value.duration ?? Duration.zero;
    if (reported.inMilliseconds > 1000) return reported;
    return widget.movie.fallbackDuration(trailer: widget.trailer) ?? reported;
  }

  /// Some containers (fragmented MP4s) never report a playback position, which
  /// leaves the scrubber dead and makes resume impossible -- the platform player
  /// simply restarts. For those we run our own clock and seek to it explicitly.
  bool get _usesVirtualClock => !_durationIsReliable;

  final Stopwatch _clock = Stopwatch();
  Duration _clockBase = Duration.zero;
  Timer? _tickTimer;

  Duration get _virtualPosition {
    final p = _clockBase + _clock.elapsed;
    final max = _effectiveDuration;
    return max > Duration.zero && p > max ? max : p;
  }

  /// The position that drives the UI, skipping and progress saving.
  Duration get _position => _usesVirtualClock
      ? _virtualPosition
      : (_controller?.value.position ?? Duration.zero);

  void _rebaseClock(Duration to) {
    _clockBase = to;
    _clock.reset();
  }

  void _syncClock() {
    final playing = _controller?.value.isPlaying ?? false;
    if (playing && !_clock.isRunning) {
      _clock.start();
    } else if (!playing && _clock.isRunning) {
      _clockBase = _virtualPosition;
      _clock.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _playback = context.read<PlaybackController>();
    _enterImmersive();
    unawaited(WakelockPlus.enable());
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final source = _source;
    if (source == null) {
      setState(() {
        _initializing = false;
        _error = 'This title has no ${widget.trailer ? 'trailer' : 'video'} available.';
      });
      return;
    }

    final old = _controller;
    _controller = null;
    await old?.dispose();

    setState(() {
      _initializing = true;
      _error = null;
    });

    final controller = VideoPlayerController.asset(source);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final resume = _tracksProgress
          ? _playback.resumePositionFor(widget.movie.id)
          : Duration.zero;
      if (resume > Duration.zero) await controller.seekTo(resume);
      _rebaseClock(resume);
      controller.addListener(_onControllerUpdate);
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      await controller.play();
      _startSaveTimer();
      _startTickTimer();
      _scheduleHide();
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'The video could not be played.';
      });
    }
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final value = controller.value;
    if (value.hasError && _error == null) {
      setState(() => _error = value.errorDescription ?? 'Playback failed.');
      return;
    }
    // Only honour "completed" once playback has actually stopped. A fragmented
    // MP4 reports a near-zero duration, so isCompleted is true from the first
    // frame; without this guard the controls pin themselves open forever and
    // never auto-hide.
    if (_isCompleted && !value.isPlaying) {
      _hideTimer?.cancel();
      _saveProgress();
      if (!_controlsVisible) setState(() => _controlsVisible = true);
    }
    _syncClock();
    // Rebuild for position / buffering / play-state changes.
    setState(() {});
  }

  // --- Orientation & system UI ------------------------------------------

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _applyOrientation();
  }

  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(
      _landscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
    );
  }

  void _toggleOrientation() {
    setState(() => _landscape = !_landscape);
    _applyOrientation();
    _showControls();
  }

  // --- Controls visibility ----------------------------------------------

  void _scheduleHide() {
    _hideTimer?.cancel();
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    _hideTimer = Timer(AppDurations.controlsAutoHide, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  // --- Playback actions -------------------------------------------------

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    // Same guard as above: a still-playing source is never "finished", whatever
    // duration it claims.
    if (_isCompleted && !controller.value.isPlaying) {
      await controller.seekTo(Duration.zero);
      await controller.play();
    } else if (controller.value.isPlaying) {
      await controller.pause();
      _saveProgress();
    } else {
      // The platform player would resume from zero for sources it cannot
      // track, so put it back where the clock says we were.
      if (_usesVirtualClock) await controller.seekTo(_virtualPosition);
      await controller.play();
    }
    _showControls();
  }

  Future<void> _skip(Duration delta) async {
    final controller = _controller;
    if (controller == null) return;
    final target = _position + delta;
    final max = _effectiveDuration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (max > Duration.zero && target > max ? max : target);
    await controller.seekTo(clamped);
    _rebaseClock(clamped);
    _showControls();
  }

  void _onScrubStart(Duration position) {
    _hideTimer?.cancel();
    setState(() => _scrubPosition = position);
  }

  void _onScrubUpdate(Duration position) =>
      setState(() => _scrubPosition = position);

  Future<void> _onScrubEnd(Duration position) async {
    setState(() => _scrubPosition = null);
    await _controller?.seekTo(position);
    _rebaseClock(position);
    _saveProgress();
    _showControls();
  }

  Future<void> _setVolume(double volume) async {
    await _controller?.setVolume(volume);
    if (volume > 0) _lastVolume = volume;
    _showControls();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    await _setVolume(controller.value.volume > 0 ? 0 : _lastVolume);
  }

  // --- Progress persistence ---------------------------------------------

  /// The platform player emits no updates when it cannot track position, so
  /// the virtual clock needs its own repaint tick.
  void _startTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && _usesVirtualClock && _clock.isRunning) setState(() {});
    });
  }

  void _startSaveTimer() {
    _saveTimer?.cancel();
    if (!_tracksProgress) return;
    _saveTimer = Timer.periodic(_progressSaveInterval, (_) => _saveProgress());
  }

  void _saveProgress() {
    if (!_tracksProgress) return;
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    unawaited(_playback.save(
      movieId: widget.movie.id,
      position: _position,
      duration: _effectiveDuration,
    ));
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _tickTimer?.cancel();
    _saveProgress();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    unawaited(WakelockPlus.disable());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final title = widget.trailer
        ? '${widget.movie.title} · Trailer'
        : widget.movie.title;

    Widget content;
    if (_error != null) {
      content = AppErrorWidget(
        title: 'Playback error',
        message: _error!,
        onRetry: _source == null ? null : _initialize,
      );
    } else if (_initializing || controller == null) {
      content = const LoadingWidget();
    } else {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            if (controller.value.isBuffering)
              const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            _DoubleTapSeekLayer(
              onSeekBackward: () => _skip(-_skipStep),
              onSeekForward: () => _skip(_skipStep),
            ),
            PlayerControls(
              visible: _controlsVisible,
              title: title,
              value: controller.value,
              duration: _effectiveDuration,
              position: _position,
              completed: _isCompleted,
              scrubPosition: _scrubPosition,
              landscape: _landscape,
              onBack: () => Navigator.of(context).maybePop(),
              onTogglePlay: _togglePlay,
              onSkipBack: () => _skip(-_skipStep),
              onSkipForward: () => _skip(_skipStep),
              onScrubStart: _onScrubStart,
              onScrubUpdate: _onScrubUpdate,
              onScrubEnd: _onScrubEnd,
              onVolumeChanged: _setVolume,
              onToggleMute: _toggleMute,
              onToggleOrientation: _toggleOrientation,
              onInteraction: _showControls,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (_error != null || _initializing || controller == null)
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Invisible left/right halves that skip on double-tap, like most players.
class _DoubleTapSeekLayer extends StatelessWidget {
  const _DoubleTapSeekLayer({
    required this.onSeekBackward,
    required this.onSeekForward,
  });

  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: onSeekBackward,
          ),
        ),
        const Spacer(),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: onSeekForward,
          ),
        ),
      ],
    );
  }
}
