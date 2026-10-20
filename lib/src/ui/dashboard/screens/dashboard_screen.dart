import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/models/facility.dart';
import '../../../data/models/saved_facility.dart';
import '../../../data/services/facility_service.dart';
import '../../core/view_model/auth_view_model.dart';
import '../../core/view_model/theme_mode_view_model.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../view_model/dashboard_view_model.dart';

/// What the dashboard asks the map to do as it closes — the web's
/// `/?view=` (a row tap) and `/?nav=` (a saved facility's Navigate).
class DashboardRequest {
  const DashboardRequest({
    required this.facilityName,
    required this.navigate,
    this.category,
    this.latitude,
    this.longitude,
  });

  final String facilityName;
  final bool navigate;
  final String? category;
  final double? latitude;
  final double? longitude;
}

/// The web's My Dashboard: welcome banner, stats, Recent Activity, Most
/// Visited and Saved Facilities.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.palette.backgroundCanvas,
      appBar: AppBar(
        backgroundColor: context.palette.backgroundSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back to Map',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          spacing: 10,
          children: [
            // The web's header logo: the white-lettered one on dark, the
            // dark-lettered one on light.
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                isDark
                    ? 'assets/images/logo_black.png'
                    : 'assets/images/logo_white.png',
                height: 32,
              ),
            ),
            Flexible(
              child: Text.rich(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: '911 ',
                      style: TextStyle(color: context.palette.primary),
                    ),
                    TextSpan(
                      text: 'Rescue',
                      style: TextStyle(color: context.palette.accentGreen),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        shape: Border(bottom: BorderSide(color: context.palette.border)),
        actions: [
          OutlinedButton(
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.palette.textPrimary,
              side: BorderSide(color: context.palette.border),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: Text(isDark ? '☀️ Light' : '🌙 Dark'),
          ),
          TextButton(
            onPressed: () async {
              if (!await confirmLogout(context)) return;
              await ref.read(authViewModelProvider.notifier).signOut();
              if (context.mounted) context.pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: context.palette.textSecondary,
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: const Text('Logout'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: switch (dashboard) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardViewModelProvider.notifier).refresh(),
          child: _DashboardBody(dashboard: value),
        ),
        AsyncError(:final error) => _Message(
          text: error is AppFailure
              ? error.userMessage
              : 'Could not load your dashboard.',
          onRetry: () => ref.invalidate(dashboardViewModelProvider),
        ),
        _ => const _Message(text: 'Loading your dashboard…'),
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 16,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void close({
      required String name,
      required bool navigate,
      String? category,
      double? latitude,
      double? longitude,
    }) {
      ref
          .read(dashboardViewModelProvider.notifier)
          .logAction(navigate ? 'navigate' : 'view');
      context.pop(
        DashboardRequest(
          facilityName: name,
          navigate: navigate,
          category: category,
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }

    final profile = dashboard.profile;
    final history = dashboard.history;
    final visited = {for (final item in history) item.facilityName}.length;
    final navigations = history
        .where((item) => item.interactionType == 'navigated')
        .length;
    final firstName = profile.name?.trim().split(' ').first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _WelcomeBanner(
          firstName: (firstName == null || firstName.isEmpty)
              ? 'User'
              : firstName,
          email: profile.email,
          plan: profile.plan,
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _StatCard(
              label: 'Facilities Visited',
              value: '$visited',
              accent: context.palette.primary,
            ),
            _StatCard(
              label: 'Saved Facilities',
              value: '${dashboard.saved.length}',
              accent: context.palette.accentGreen,
            ),
            _StatCard(
              label: 'Navigations',
              value: '$navigations',
              accent: context.palette.danger,
            ),
            _StatCard(
              label: 'Member Since',
              value: _monthYear(profile.createdAt),
              accent: context.palette.accentYellow,
              small: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Recent Activity',
          subtitle: 'Last 20 interactions',
          children: history.isEmpty
              ? const [
                  _Empty(
                    icon: '🗺️',
                    text:
                        'No activity yet. Start exploring facilities on the '
                        'map!',
                  ),
                ]
              : [
                  for (final item in history)
                    _Row(
                      onTap: () => close(
                        name: item.facilityName,
                        navigate: false,
                        category: item.facilityCategory,
                      ),
                      icon: _IconBox(
                        child: Text(
                          _categoryEmoji(item.facilityCategory),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      title: item.facilityName,
                      tag: _ActivityTag(type: item.interactionType),
                      subtitle: [
                        item.facilityCategory ?? 'Health Facility',
                        if (item.mode != null) item.mode!,
                      ].join(' · '),
                      trailing: _Muted(_timeAgo(item.createdAt)),
                    ),
                ],
        ),
        _Section(
          title: 'Most Visited',
          children: dashboard.topFacilities.isEmpty
              ? const [_Empty(icon: '🏥', text: 'No visits recorded yet.')]
              : [
                  for (final (index, item) in dashboard.topFacilities.indexed)
                    _Row(
                      onTap: () => close(
                        name: item.facilityName,
                        navigate: false,
                        category: item.facilityCategory,
                      ),
                      icon: _IconBox(
                        color: context.palette.accentGreen,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: context.palette.accentGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      title: item.facilityName,
                      subtitle: item.facilityCategory,
                      trailing: _Muted(
                        '${item.visits} visit${item.visits == 1 ? '' : 's'}',
                      ),
                    ),
                ],
        ),
        _Section(
          title: 'Saved Facilities',
          action: TextButton(
            onPressed: () => context.pop(),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.primary,
              textStyle: const TextStyle(fontSize: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('+ Add from map'),
          ),
          children: dashboard.saved.isEmpty
              ? const [
                  _Empty(
                    icon: '⭐',
                    text:
                        'No saved facilities yet. Tap ⭐ on any facility '
                        'popup to save it.',
                  ),
                ]
              : [
                  for (final item in dashboard.saved)
                    _SavedRow(
                      item: item,
                      onNavigate: item.latitude == null
                          ? null
                          : () => close(
                              name: item.name,
                              navigate: true,
                              category: item.category,
                              latitude: item.latitude,
                              longitude: item.longitude,
                            ),
                      onRemove: () => ref
                          .read(dashboardViewModelProvider.notifier)
                          .removeSaved(item.name),
                    ),
                ],
        ),
        const _DeleteAccount(),
      ],
    );
  }
}

/// Deleting the account from inside the app — both stores require it for
/// any app that creates accounts.
class _DeleteAccount extends ConsumerStatefulWidget {
  const _DeleteAccount();

  @override
  ConsumerState<_DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends ConsumerState<_DeleteAccount> {
  var _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your 911 Rescue account, the facilities '
          'saved to it and your activity history. Facilities saved on this '
          'phone stay on this phone. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.danger,
            ),
            child: const Text(
              'Delete account',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    final error = await ref
        .read(authViewModelProvider.notifier)
        .deleteAccount();
    if (!mounted) return;
    setState(() => _deleting = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account has been deleted.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          OutlinedButton(
            onPressed: _deleting ? null : _delete,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.palette.danger,
              side: BorderSide(color: context.palette.danger),
            ),
            child: Text(_deleting ? 'Deleting…' : 'Delete account'),
          ),
          const SizedBox(height: 6),
          Text(
            'Removes your account, saved facilities and history.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.firstName,
    required this.email,
    this.plan,
  });

  final String firstName;
  final String email;
  final String? plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.palette.primary, context.palette.accentGreen],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $firstName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${(plan ?? 'free').toUpperCase()} Plan',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
    this.small = false,
  });

  final String label;
  final String value;
  final Color accent;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Container(
      decoration: BoxDecoration(
        color: context.palette.backgroundSurface,
        borderRadius: radius,
        border: Border.all(color: context.palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(color: accent, child: const SizedBox(width: 4)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: small ? 16 : 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The web's dashboard card: a titled panel of rows.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: context.palette.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.palette.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (subtitle != null) _Muted(subtitle!, fontSize: 12),
                ?action,
              ],
            ),
          ),
          for (final (index, child) in children.indexed) ...[
            if (index > 0) Divider(height: 1, color: context.palette.border),
            child,
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.tag,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget icon;
  final String title;
  final Widget? tag;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: title,
                      children: [
                        if (tag != null)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: tag,
                            ),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    _Muted(subtitle!),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.item,
    required this.onNavigate,
    required this.onRemove,
  });

  final SavedFacility item;
  final VoidCallback? onNavigate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _Row(
      icon: const _IconBox(child: Text('⭐', style: TextStyle(fontSize: 16))),
      title: item.name,
      subtitle: item.category,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (onNavigate != null)
            _Pill(
              label: 'Navigate',
              onTap: onNavigate!,
              fill: context.palette.accentGreen,
              foreground: context.palette.onAccent,
            ),
          _Pill(
            label: 'Remove',
            onTap: onRemove,
            foreground: context.palette.danger,
            outline: context.palette.danger,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    required this.foreground,
    this.fill,
    this.outline,
  });

  final String label;
  final VoidCallback onTap;
  final Color foreground;
  final Color? fill;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: outline == null ? BorderSide.none : BorderSide(color: outline!),
    );
    return Material(
      color: fill ?? Colors.transparent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: fill == null ? FontWeight.w400 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// The web's `.fac-icon`: a 36px rounded tile, blue-tinted by default.
class _IconBox extends StatelessWidget {
  const _IconBox({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: (color ?? context.palette.primary).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

/// The web's `.tag`: nav green, analyzed yellow, anything else blue.
class _ActivityTag extends StatelessWidget {
  const _ActivityTag({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'navigated' => context.palette.accentGreen,
      'analyzed' => context.palette.accentYellow,
      _ => context.palette.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
    child: Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text, {this.fontSize = 11});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: context.palette.textSecondary, fontSize: fontSize),
  );
}

/// The web's category icons for a raw category string.
String _categoryEmoji(String? rawCategory) =>
    switch (classifyFacilityCategory(rawCategory)) {
      FacilityCategory.health => '🏥',
      FacilityCategory.police => '🚓',
      FacilityCategory.fire => '🚒',
      FacilityCategory.roadSafety => '🚧',
      FacilityCategory.other => '📍',
    };

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. "Oct 2026", as the web's `en-GB` month/year.
String _monthYear(DateTime? date) =>
    date == null ? '—' : '${_months[date.month - 1]} ${date.year}';

/// The web's relative time: just now, 5m ago, 3h ago, 2d ago.
String _timeAgo(DateTime? date) {
  if (date == null) return '';
  final minutes = DateTime.now().difference(date).inMinutes;
  if (minutes < 1) return 'just now';
  if (minutes < 60) return '${minutes}m ago';
  final hours = minutes ~/ 60;
  return hours < 24 ? '${hours}h ago' : '${hours ~/ 24}d ago';
}
