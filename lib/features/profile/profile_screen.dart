import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/app_user.dart';
import '../../models/movie.dart';
import '../../navigation/app_router.dart';
import '../../services/api/nova_api.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/movie_section.dart';
import '../../widgets/user_avatar.dart';
import '../auth/auth_controller.dart';
import '../home/catalog_controller.dart';
import '../player/playback_controller.dart';
import '../watchlist/watchlist_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final auth = context.read<AuthController>();
    final controller = TextEditingController(text: auth.user?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Edit your name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'First name'),
            validator: Validators.name,
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialog).pop(controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialog).pop(controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !context.mounted) return;
    try {
      await auth.updateName(name);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message, isError: true);
      return;
    }
    if (context.mounted) {
      showAppSnackBar(context, 'Name updated', icon: Icons.check_rounded);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your list and progress stay saved on this device, and your plan '
          'stays with your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthController>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final playback = context.watch<PlaybackController>();
    final watchlist = context.watch<WatchlistController>();
    final catalog = context.watch<CatalogController>();
    final text = Theme.of(context).textTheme;

    final user = auth.user;
    final plan = user?.hasActivePlan == true ? user!.subscription : null;
    final continueWatching = playback.continueWatching
        .map((p) => catalog.byId(p.movieId))
        .whereType<Movie>()
        .toList();
    final recentlyWatched = playback.watched
        .map((p) => catalog.byId(p.movieId))
        .whereType<Movie>()
        .toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 80 + bottomInset),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xl,
              ),
              child: Text('Profile', style: text.headlineLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Row(
                children: [
                  const UserAvatar(size: 72, accent: true),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name.isNotEmpty == true ? user!.name : 'Member',
                          style: text.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: text.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _PlanPill(plan: plan),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit name',
                    onPressed: () => _editName(context),
                    icon: const Icon(Icons.edit_outlined),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Row(
                children: [
                  _StatTile(
                    icon: Icons.bookmark_rounded,
                    value: '${watchlist.count}',
                    label: 'In My List',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _StatTile(
                    icon: Icons.play_circle_outline_rounded,
                    value: '${continueWatching.length}',
                    label: 'In Progress',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _StatTile(
                    icon: Icons.check_circle_outline_rounded,
                    value: '${recentlyWatched.length}',
                    label: 'Watched',
                  ),
                ],
              ),
            ),
            if (continueWatching.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              MovieSection(
                title: 'Continue Watching',
                movies: continueWatching,
                heroPrefix: 'profile-continue',
                onMovieTap: (m) => context.openPlayer(m),
                progressBuilder: (m) => playback.progressFor(m.id)?.fraction,
                subtitleBuilder: (m) {
                  final p = playback.progressFor(m.id);
                  return p == null
                      ? null
                      : Formatters.minutesLeft(p.position, p.duration);
                },
              ),
            ],
            if (recentlyWatched.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              MovieSection(
                title: 'Recently Watched',
                movies: recentlyWatched,
                heroPrefix: 'profile-watched',
                onMovieTap: (m) =>
                    context.openDetails(m, heroTag: 'profile-watched-${m.id}'),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            _SettingsGroup(
              title: 'Subscription',
              children: [
                _SettingsRow(
                  icon: Icons.workspace_premium_outlined,
                  title:
                      plan == null ? 'No plan selected' : '${plan.planName} plan',
                  subtitle: plan == null
                      ? 'Choose a plan to start watching'
                      : '${plan.price.formatted}/month • ${plan.quality} • '
                          'Renews ${Formatters.date(plan.currentPeriodEnd)}',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.plans,
                    arguments: const PlanArgs(popOnSave: true),
                  ),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Playback',
              children: [
                _SettingsRow(
                  icon: Icons.skip_next_outlined,
                  title: 'Autoplay next episode',
                  subtitle: 'Automatically play the next episode',
                  trailing: Switch(
                    value: playback.settings.autoplayNext,
                    onChanged: (v) => playback.updateSettings(
                      playback.settings.copyWith(autoplayNext: v),
                    ),
                  ),
                ),
                _SettingsRow(
                  icon: Icons.preview_outlined,
                  title: 'Autoplay previews',
                  subtitle: 'Play previews while browsing',
                  trailing: Switch(
                    value: playback.settings.autoplayPreviews,
                    onChanged: (v) => playback.updateSettings(
                      playback.settings.copyWith(autoplayPreviews: v),
                    ),
                  ),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Account',
              children: [
                _SettingsRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email',
                  subtitle: user?.email ?? '',
                ),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: 'End your session on this device',
                  destructive: true,
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanPill extends StatelessWidget {
  const _PlanPill({required this.plan});

  final UserSubscription? plan;

  @override
  Widget build(BuildContext context) {
    final active = plan != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0x33E50914) : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: active ? const Color(0x80E50914) : AppColors.border,
        ),
      ),
      child: Text(
        active ? '${plan!.planName} • ${plan!.quality}' : 'No plan',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: active ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: text.headlineMedium),
            const SizedBox(height: 2),
            Text(
              label,
              style: text.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: destructive ? AppColors.error : AppColors.textSecondary),
      title: Text(title, style: text.titleMedium?.copyWith(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: text.bodySmall),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
    );
  }
}
