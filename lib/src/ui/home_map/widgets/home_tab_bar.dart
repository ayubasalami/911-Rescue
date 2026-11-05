import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum HomeTab {
  info('Info', Icons.info_outline, Icons.info),
  discover('Discover', Icons.explore_outlined, Icons.explore),
  chat('Chat', Icons.chat_bubble_outline, Icons.chat_bubble),
  profile('Profile', Icons.person_outline, Icons.person);

  const HomeTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The four always-visible buttons under the map. [selected] is null while
/// the sheet shows something that isn't a tab — search.
class HomeTabBar extends StatelessWidget {
  const HomeTabBar({super.key, required this.selected, required this.onTap});

  final HomeTab? selected;
  final ValueChanged<HomeTab> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.backgroundSurface,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final tab in HomeTab.values)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(tab),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tab == selected
                                ? palette.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                          ),
                          child: Icon(
                            tab == selected ? tab.selectedIcon : tab.icon,
                            size: 22,
                            color: tab == selected
                                ? palette.primary
                                : palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: tab == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: tab == selected
                                ? palette.primary
                                : palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
