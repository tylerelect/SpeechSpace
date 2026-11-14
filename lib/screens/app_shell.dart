import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import 'calendar_page.dart';
import 'mind_map_page.dart';
import 'settings_page.dart';
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: widget.controller, builder: (context, _) {
      final controller = widget.controller;
      if (controller.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            const Text('For an immediate demo, run without API_BASE_URL.', textAlign: TextAlign.center),
          ])))));
      }

      const destinations = <NavigationDestination>[
        NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Today'),
        NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
        NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories), label: 'Memories'),
        NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Mind map'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
      ];
      final pages = [
        TodayPage(controller: controller),
        CalendarPage(controller: controller),
        TimelinePage(controller: controller),
        MindMapPage(controller: controller),
        SettingsPage(controller: controller),
      ];
      final wide = MediaQuery.sizeOf(context).width >= 880;
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Row(children: [
            const Icon(Icons.auto_stories_rounded, color: Color(0xFF7565AF)),
            const SizedBox(width: 10),
            const Flexible(child: Text('SpeechSpace', overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.4))),
            if (controller.demo && MediaQuery.sizeOf(context).width >= 760) ...[
              const SizedBox(width: 12),
              const Chip(label: Text('DEMO • not saved'), visualDensity: VisualDensity.compact),
            ],
          ]),
          actions: [
            if (controller.children.isNotEmpty)
              DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: controller.selectedChildId,
                items: controller.children.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (id) { if (id != null) controller.selectChild(id); },
              )),
            const SizedBox(width: 16),
          ],
        ),
        body: Row(children: [
          if (wide)
            NavigationRail(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              selectedIndex: _selected,
              onDestinationSelected: (i) => setState(() => _selected = i),
              extended: MediaQuery.sizeOf(context).width >= 1120,
              leading: const SizedBox(height: 12),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: Text('Today')),
                NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('Calendar')),
                NavigationRailDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories), label: Text('Memories')),
                NavigationRailDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: Text('Mind map')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
              ],
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: controller.child == null && _selected != 4
              ? _NoChild(controller: controller)
              : pages[_selected]),
        ]),
        bottomNavigationBar: wide ? null : NavigationBar(
          selectedIndex: _selected,
          onDestinationSelected: (i) => setState(() => _selected = i),
          destinations: destinations,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        ),
      );
    });
  }
}

class _NoChild extends StatelessWidget {
  const _NoChild({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.child_care, size: 66),
    const SizedBox(height: 12),
    const Text('Start by adding a child profile in Settings'),
    const SizedBox(height: 8),
    TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open Settings to create a profile.'))), child: const Text('Got it')),
  ]));
}
