import 'package:flutter/material.dart';

import '../services/app_controller.dart';

/// "All entries" plus one chip per project. Selecting one filters every screen.
class ProjectFilter extends StatelessWidget {
  const ProjectFilter({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final projects = controller.profileProjects;
    if (projects.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      const Icon(Icons.folder_outlined, size: 18),
      const SizedBox(width: 8),
      ChoiceChip(label: const Text('All entries'), selected: controller.selectedProjectId.isEmpty,
          onSelected: (_) => controller.selectProject('')),
      for (final p in projects) Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(
        label: Text(p.name), selected: controller.selectedProjectId == p.id,
        onSelected: (_) => controller.selectProject(controller.selectedProjectId == p.id ? '' : p.id),
      )),
    ]));
  }
}
