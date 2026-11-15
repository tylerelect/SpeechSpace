import 'package:flutter/material.dart';

import '../models/calendar.dart';
import '../models/models.dart';
import '../services/app_controller.dart';
import '../theme/space_themes.dart';
import '../widgets/space_art.dart';
import 'activity_heatmap_page.dart';
import 'calendar_page.dart';
import 'mind_map_page.dart';
import 'profile_setup_page.dart';
import 'settings_page.dart';
import 'start_page.dart';
import 'timeline_page.dart';
import 'today_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;

  static const calendarTab = 1;
  static const activityTab = 4;
  static const settingsTab = 5;

  /// Narrow layouts show the first [_primaryTabs] destinations plus "More".
  static const _primaryTabs = 4;

  void _openDay(DateTime date) {
    widget.controller.setCalendar(CalendarView.day, date);
    setState(() => _selected = calendarTab);
  }

  Future<void> _openMore(BuildContext context, List<(IconData, IconData, String)> nav) async {
    final choice = await showModalBottomSheet<int>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = _primaryTabs; i < nav.length; i++) ListTile(
          key: ValueKey('more-$i'),
          leading: Icon(_selected == i ? nav[i].$2 : nav[i].$1),
          title: Text(nav[i].$3),
          selected: _selected == i,
          trailing: _selected == i ? const Icon(Icons.check) : null,
          onTap: () => Navigator.pop(ctx, i),
        ),
        const SizedBox(height: 8),
      ]),
    ));
    if (choice != null && mounted) setState(() => _selected = choice);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: widget.controller, builder: (context, _) {
      final controller = widget.controller;
      if (controller.loading) {
        return const Scaffold(body: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Opening SpeechSpace'),
          SizedBox(height: 8),
          Text('Loading your profiles and memories…'),
        ],
      )));
      }
      if (controller.loadError != null) {
        return Scaffold(body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 18),
            const Text('Cannot connect to the backend', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(controller.loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: controller.initialize, child: const Text('Retry')),
            const SizedBox(height: 12),
            const Text('Check your connection and backend access settings, then retry.', textAlign: TextAlign.center),
          ])))));
      }

      if (!controller.started) return StartPage(controller: controller);
      final copy = controller.copy;
      final scheme = Theme.of(context).colorScheme;
      final nav = <(IconData, IconData, String)>[
        (Icons.wb_sunny_outlined, Icons.wb_sunny, copy.navToday),
        (Icons.calendar_month_outlined, Icons.calendar_month, copy.navCalendar),
        (Icons.auto_stories_outlined, Icons.auto_stories, copy.navMemories),
        // Kids: the map is named and drawn for the active theme (Star, Sea or Garden map).
        if (copy.isKids)
          (KidsDecor.of(controller.spaceTheme.id).navIcon, KidsDecor.of(controller.spaceTheme.id).navIconSelected,
              KidsDecor.of(controller.spaceTheme.id).mapName)
        else
          (Icons.hub_outlined, Icons.hub, copy.navMindMap),
        (Icons.grid_view_outlined, Icons.grid_view_rounded, copy.navActivity),
        (Icons.settings_outlined, Icons.settings, copy.navSettings),
      ];
      final pages = [
        TodayPage(controller: controller),
        CalendarPage(controller: controller),
        TimelinePage(controller: controller),
        MindMapPage(controller: controller),
        ActivityHeatmapPage(controller: controller, onOpenDay: _openDay),
        SettingsPage(controller: controller),
      ];
      final width = MediaQuery.sizeOf(context).width;
      final wide = width >= 880;
      // Each Kids theme paints its own scene (night sky, sea, meadow) behind the whole shell.
      final sky = controller.isKids;
      final scaffold = Scaffold(
        backgroundColor: sky ? Colors.transparent : null,
        appBar: AppBar(
          backgroundColor: sky ? Colors.transparent : null,
          toolbarHeight: 72,
          title: Row(children: [
            Icon(controller.isKids ? Icons.rocket_launch_rounded : Icons.auto_stories_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            const Flexible(child: Text('SpeechSpace', overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.4))),
            if (controller.demo && width >= 760) ...[
              const SizedBox(width: 12),
              const Chip(label: Text('DEMO • not saved'), visualDensity: VisualDensity.compact),
            ],
          ]),
          actions: [
            if (controller.isKids) ListenableBuilder(listenable: controller.sound, builder: (context, _) => IconButton(
              tooltip: controller.sound.musicOn ? 'Turn music off' : 'Play music',
              onPressed: controller.sound.toggleMusic,
              icon: Icon(controller.sound.musicOn ? Icons.music_note_rounded : Icons.music_off_outlined),
            )),
            if (controller.profiles.isNotEmpty) _ProfilePicker(controller: controller),
            const SizedBox(width: 12),
          ],
        ),
        body: Row(children: [
          if (wide)
            NavigationRail(
              backgroundColor: sky ? Colors.transparent : null,
              selectedIndex: _selected,
              onDestinationSelected: (i) => setState(() => _selected = i),
              extended: width >= 1120,
              leading: const SizedBox(height: 12),
              destinations: [for (final n in nav)
                NavigationRailDestination(icon: Icon(n.$1), selectedIcon: Icon(n.$2), label: Text(n.$3))],
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: controller.profile == null && _selected != settingsTab
              ? _NoChild(controller: controller)
              : pages[_selected]),
        ]),
        // Six destinations don't fit a phone-width bar: keep four plus "More"
        // (Activity, Settings) so labels never overflow.
        bottomNavigationBar: wide ? null : NavigationBar(
          selectedIndex: _selected < _primaryTabs ? _selected : _primaryTabs,
          onDestinationSelected: (i) => i < _primaryTabs ? setState(() => _selected = i) : _openMore(context, nav),
          destinations: [
            for (final n in nav.take(_primaryTabs))
              NavigationDestination(icon: Icon(n.$1), selectedIcon: Icon(n.$2), label: n.$3),
            NavigationDestination(
              key: const ValueKey('nav-more'),
              icon: const Icon(Icons.more_horiz),
              selectedIcon: Icon(_selected == activityTab ? nav[activityTab].$2 : nav[settingsTab].$2),
              label: _selected >= _primaryTabs ? nav[_selected].$3 : 'More',
              tooltip: 'More: ${nav.skip(_primaryTabs).map((n) => n.$3).join(', ')}',
            ),
          ],
          labelBehavior: copy.isKids
              ? NavigationDestinationLabelBehavior.alwaysShow
              : NavigationDestinationLabelBehavior.onlyShowSelected,
        ),
      );
      // Same tree shape either way so switching profiles keeps page state.
      return Stack(children: [Positioned.fill(child: sky ? ThemeBackdrop(controller.spaceTheme.id) : const SizedBox.shrink()), scaffold]);
    });
  }
}

/// App-bar profile switcher that labels each profile as Kids or Adult.
class _ProfilePicker extends StatelessWidget {
  const _ProfilePicker({required this.controller});
  static const _newProfile = '__new_profile__';
  static const _switchUser = '__switch_user__';
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.profile;
    return PopupMenuButton<String>(
      tooltip: 'Switch profile',
      onSelected: (value) async {
        if (value == _newProfile) {
          await openProfileSetup(context, controller);
        } else if (value == _switchUser) {
          await controller.switchUser();
        } else {
          controller.selectProfile(value);
        }
      },
      itemBuilder: (_) => [for (final p in controller.profiles) PopupMenuItem(
        value: p.id,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ProfileAvatar(profile: p),
          title: Text(p.name),
          subtitle: Text(p.isKids ? 'Kids' : 'Adult'),
          trailing: p.id == current?.id ? const Icon(Icons.check) : null,
        ),
      ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _newProfile, child: ListTile(contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_add_alt_1), title: Text('New profile…'))),
        const PopupMenuItem(value: _switchUser, child: ListTile(contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.switch_account_outlined), title: Text('Switch user'))),
      ],
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (current != null) ProfileAvatar(profile: current, radius: 16),
        const SizedBox(width: 8),
        if (current != null) Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(current.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(current.isKids ? 'Kids' : 'Adult', style: Theme.of(context).textTheme.labelSmall),
        ]),
        const Icon(Icons.arrow_drop_down),
      ])),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 20});
  final SpaceProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = resolveTheme(profile.themeId, profile.kind);
    return CircleAvatar(
      radius: radius,
      backgroundColor: t.seed.withValues(alpha: .2),
      foregroundColor: t.seed,
      child: Icon(profile.isKids ? Icons.rocket_launch_rounded : Icons.person_outline, size: radius),
    );
  }
}

class _NoChild extends StatelessWidget {
  const _NoChild({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.child_care, size: 66),
    const SizedBox(height: 12),
    const Text('Start by adding a profile in Settings'),
    const SizedBox(height: 8),
    TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open Settings to create a profile.'))), child: const Text('Got it')),
  ]));
}
