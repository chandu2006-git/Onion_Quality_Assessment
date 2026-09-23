import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../providers/inspection_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import 'brand_mark.dart';
import 'responsive_layout.dart';

/// Global navigation entry.
class _NavItem {
  const _NavItem(this.label, this.path);
  final String label;
  final String path;
}

const List<_NavItem> _navItems = <_NavItem>[
  _NavItem('Home', '/'),
  _NavItem('Start Inspection', '/start'),
  _NavItem('Methodology & Standards', '/about'),
];

/// Page chrome shared by every screen: clean header navigation and a subtle
/// footer. Only the five product pages exist — no dashboards or admin entries.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 900;
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      drawer: narrow ? const _NavigationDrawer() : null,
      body: Column(
        children: [
          _AppHeader(narrow: narrow),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AppHeader extends ConsumerWidget {
  const _AppHeader({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final session = ref.watch(inspectionProvider).session;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: ContentContainer(
          maxWidth: AppTheme.maxContentWidth,
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? AppTheme.gutter : AppTheme.s32,
            vertical: AppTheme.s16,
          ),
          child: Row(
            children: [
              if (narrow)
                Builder(
                  builder: (context) => IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu),
                    color: AppTheme.primary,
                    tooltip: 'Open navigation menu',
                  ),
                ),
              InkWell(
                onTap: () => context.go('/'),
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: BrandMark(),
                ),
              ),
              const Spacer(),
              if (!narrow) ...[
                ..._navItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      onPressed: () => context.go(item.path),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isActive(path, item.path)
                              ? AppTheme.primary
                              : AppTheme.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.md),
              ],
              FilledButton(
                onPressed: () => context.go(session == null ? '/start' : '/capture'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 16 : 22,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                child: Text(narrow ? 'START' : 'START INSPECTION'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isActive(String current, String target) {
    if (target == '/') return current == '/';
    return current.startsWith(target);
  }
}

class _NavigationDrawer extends StatelessWidget {
  const _NavigationDrawer();

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Drawer(
      backgroundColor: AppTheme.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppTheme.s24),
              child: BrandMark(),
            ),
            const Divider(height: 1),
            ..._navItems.map(
              (item) => ListTile(
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _AppHeader._isActive(path, item.path)
                        ? AppTheme.primary
                        : AppTheme.secondaryText,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.path);
                },
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppTheme.s24),
              child: Text(AppConfig.assistantDisclaimer, style: AppTypo.meta),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle footer used at the end of every page.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.charcoal,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.s48),
      child: ContentContainer(
        maxWidth: AppTheme.maxContentWidth,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.s32,
          vertical: AppTheme.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(onDark: true),
            const SizedBox(height: AppTheme.md),
            Text(
              AppConfig.tagline,
              style: AppTypo.meta.copyWith(color: AppTheme.lightGreen),
            ),
            const SizedBox(height: AppTheme.s8),
            Text(
              AppConfig.assistantDisclaimer,
              style: AppTypo.meta.copyWith(
                color: AppTheme.lightGreen,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppTheme.s24),
            Wrap(
              spacing: AppTheme.s24,
              runSpacing: AppTheme.s8,
              children: [
                _FooterLink(
                  label: 'Methodology & Standards',
                  onTap: () => context.go('/about'),
                ),
                _FooterLink(
                  label: 'Technical Information',
                  onTap: () => context.go('/about'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.s24),
            Text(
              'AI-assisted inspection tool. It does not assign official AGMARK grades, '
              'does not provide disease-specific diagnosis and does not replace '
              'regulatory or expert inspection.',
              style: AppTypo.meta.copyWith(
                color: AppTheme.secondaryText,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: AppTheme.secondaryGreen,
        ),
      ),
    );
  }
}

