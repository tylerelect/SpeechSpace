import 'package:flutter/material.dart';

import '../services/app_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add a child profile'),
      content: TextField(controller: name, maxLength: 40, autofocus: true,
          decoration: const InputDecoration(labelText: 'First name or nickname')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, name.text.trim()), child: const Text('Create'))],
    ));
    name.dispose();
    if (result == null || result.trim().isEmpty || !context.mounted) return;
    try {
      await controller.addChild(result);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    if (controller.child == null) return;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete this child profile?'),
      content: const Text('This permanently deletes the profile, its memories, and connections.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (yes != true || !context.mounted) return;
    try { await controller.deleteCurrentChild(); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 850),
    child: ListView(padding: const EdgeInsets.all(22), children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('About SpeechSpace', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text("An interactive speech service to help parents have an at-a-glance view of their child's development, personally and productively."),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Child profiles', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...controller.children.map((c) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.child_care)),
          title: Text(c.name),
          trailing: c.id == controller.selectedChildId ? const Icon(Icons.check_circle) : null,
          onTap: () => controller.selectChild(c.id),
        )),
        Wrap(spacing: 12, children: [
          OutlinedButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.person_add_alt_1), label: const Text('Add profile')),
          if (controller.child != null) OutlinedButton.icon(onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline), label: const Text('Delete selected')),
        ]),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Integrations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _setting(Icons.storage_outlined, 'MongoDB Atlas', controller.demo ? 'Not connected • memory-only demo' : 'Connected through backend API'),
        _setting(Icons.auto_awesome_outlined, 'Gemini Flash', 'Optional backend text analysis • configure GEMINI_API_KEY and GEMINI_MODEL'),
        _setting(Icons.mic_none_outlined, 'Voice transcription', 'Model undecided • configure STT_ENDPOINT_URL for an external speech service'),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Privacy and guardian controls', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const Text('Prototype only. Do not enter real children\'s personal data until guardian sign-in, verified consent, access controls, security review, privacy notices, and a retention policy are complete.'),
        const SizedBox(height: 9),
        const Text('Microphone use is initiated by the user. Voice uploads are processed only through your configured backend. This app does not infer medical or developmental diagnoses.'),
        const SizedBox(height: 9),
        if (controller.demo) const Text('Demo mode: changes are only held in memory and disappear when the application restarts.'),
      ]))),
    ]),
  ));

  Widget _setting(IconData icon, String title, String sub) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon), title: Text(title), subtitle: Text(sub),
  );
}
