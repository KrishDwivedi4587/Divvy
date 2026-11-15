import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The bottom navigation: Home, Bills, a prominent New button, People and
/// Account. New is an action (it starts the Create Bill flow), not a tab.
class DivvyBottomBar extends StatelessWidget {
  const DivvyBottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onNew,
    super.key,
  });

  /// 0 Home, 1 Bills, 2 People, 3 Account.
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        // Tab labels stop growing at 1.2x, as iOS does for its own tab bars: a
        // five-item bar cannot hold larger text, and the labels sit beside
        // icons that already say what each tab is.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _Item(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: () => onSelect(0),
                ),
                _Item(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Bills',
                  selected: currentIndex == 1,
                  onTap: () => onSelect(1),
                ),
                Expanded(child: _NewButton(onTap: onNew)),
                _Item(
                  icon: Icons.group_outlined,
                  activeIcon: Icons.group_rounded,
                  label: 'People',
                  selected: currentIndex == 2,
                  onTap: () => onSelect(2),
                ),
                _Item(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Account',
                  selected: currentIndex == 3,
                  onTap: () => onSelect(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.textPrimary : c.textTertiary;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  letterSpacing: 0,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewButton extends StatelessWidget {
  const _NewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'New bill',
      excludeSemantics: true,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
            child: Icon(Icons.add_rounded, color: c.onInk, size: 28),
          ),
        ),
      ),
    );
  }
}
