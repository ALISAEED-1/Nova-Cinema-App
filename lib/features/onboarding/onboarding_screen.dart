import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../navigation/app_router.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/nova_wordmark.dart';
import 'onboarding_slide.dart';

/// Three-page intro carousel shown once, before sign-in.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<OnboardingSlide> _slides = OnboardingSlide.all;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    await context.read<OnboardingService>().markSeen();
    if (!mounted) return;
    // First run goes straight into sign-up; returning users tap "Sign in"
    // from there.
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.register, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    // Runs from the very top edge — behind the status bar and the wordmark, so
    // there is no seam — and dissolves into black just above the heading.
    final artHeight = (responsive.height * 0.62).clamp(340.0, 780.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SizedBox(
            height: artHeight,
            width: double.infinity,
            child: _Artwork(
              slides: _slides,
              controller: _controller,
              page: _page,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    0,
                  ),
                  child: Row(
                    children: [
                      const NovaWordmark(size: 26),
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: _isLast ? 0 : 1,
                        duration: AppDurations.normal,
                        child: IgnorePointer(
                          ignoring: _isLast,
                          child: TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                            ),
                            // Sits directly on the artwork, which is bright in
                            // places — the shadow keeps it readable throughout.
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    color: Color(0xCC000000),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // The copy is bottom-aligned inside this area, so it settles
                // just above the bottom bar regardless of the artwork height.
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _SlideCopy(
                      slide: _slides[i],
                      maxWidth: responsive.contentMaxWidth,
                    ),
                  ),
                ),
                _BottomBar(
                  index: _page,
                  count: _slides.length,
                  action: _slides[_page].action,
                  onNext: _next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Edge-to-edge artwork that cross-fades as the pager scrolls, then dissolves
/// into the background so the copy below sits on solid black.
class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.slides,
    required this.controller,
    required this.page,
  });

  final List<OnboardingSlide> slides;
  final PageController controller;
  final int page;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            // Fall back to the settled page until the controller has a size.
            final value =
                controller.hasClients && controller.position.haveDimensions
                    ? controller.page ?? page.toDouble()
                    : page.toDouble();
            return Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < slides.length; i++)
                  Opacity(
                    opacity: (1 - (value - i).abs()).clamp(0.0, 1.0),
                    child: AppImage(
                      slides[i].image,
                      alignment: Alignment.topCenter,
                      fadeIn: false,
                    ),
                  ),
              ],
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Scrim at the very top keeps the wordmark and Skip readable over
              // the artwork; the long tail dissolves the bottom edge into the
              // background so no seam is visible where the image ends.
              colors: [
                Color(0x99050608),
                Color(0x14050608),
                Color(0x59050608),
                Color(0xE6050608),
                AppColors.background,
              ],
              stops: [0, 0.26, 0.62, 0.87, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.slide, required this.maxWidth});

  final OnboardingSlide slide;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.bottomLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide.titleLead,
                style: text.displayLarge?.copyWith(height: 1.05),
              ),
              Text(
                slide.titleAccent,
                style: text.displayLarge
                    ?.copyWith(height: 1.05, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                slide.body,
                style: text.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.count,
    required this.action,
    required this.onNext,
  });

  final int index;
  final int count;
  final String action;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            AnimatedContainer(
              duration: AppDurations.normal,
              curve: Curves.easeOut,
              width: i == index ? 30 : 22,
              height: 5,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: i == index ? AppColors.primary : AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${(index + 1).toString().padLeft(2, '0')} / '
            '${count.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          _ActionButton(label: action, onPressed: onNext),
        ],
      ),
    );
  }
}

/// Red pill button with a trailing arrow, sized to its label.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 16,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: AppDurations.normal,
                curve: Curves.easeOut,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Icon(Icons.arrow_forward_rounded,
                  size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
