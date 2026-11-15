import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../services/sound_service.dart';
import '../theme/space_themes.dart';
import 'app_shell.dart' show ProfileAvatar;
import 'profile_setup_page.dart';
import '../widgets/commander_video.dart';
import '../widgets/profile_details_form.dart';
import '../models/models.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  Future<void> _add(BuildContext context) => openProfileSetup(context, controller);

  Future<void> _delete(BuildContext context) async {
    final profile = controller.profile;
    if (profile == null) return;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Delete ${profile.name}\'s profile?'),
      content: Text('This permanently deletes this ${profile.isKids ? 'Kids' : 'Adult'} profile, its memories, and connections.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (yes != true || !context.mounted) return;
    try { await controller.deleteCurrentProfile(); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _setTheme(BuildContext context, String id) async {
    try { await controller.setTheme(id); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    return Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 850),
    child: ListView(padding: const EdgeInsets.all(22), children: [
      Row(children: [
        Expanded(child: Text(controller.copy.navSettings, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
        IconButton(
          tooltip: 'Integration information',
          icon: const Icon(Icons.help_outline),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _IntegrationsPage(controller: controller),
          )),
        ),
      ]),
      if (controller.isKids) const Padding(padding: EdgeInsets.only(top: 4),
          child: Text('These settings are for a parent or guardian.')),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Profiles', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...controller.profiles.map((p) => ListTile(
          leading: ProfileAvatar(profile: p),
          title: Text(p.name),
          subtitle: Text(p.isKids ? 'Kids' : 'Adult'),
          trailing: p.id == controller.selectedProfileId ? const Icon(Icons.check_circle) : null,
          onTap: () => controller.selectProfile(p.id),
        )),
        Wrap(spacing: 12, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.person_add_alt_1), label: const Text('Add profile')),
          if (profile != null) OutlinedButton.icon(onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline), label: const Text('Delete selected')),
        ]),
      ]))),
      if (profile != null) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Theme for ${profile.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final t in themesFor(profile.kind)) ChoiceChip(
              key: ValueKey('theme-${t.id}'),
              avatar: CircleAvatar(backgroundColor: t.seed, child: Icon(t.icon, size: 14, color: Colors.white)),
              label: Text(t.label),
              selected: controller.spaceTheme.id == t.id,
              onSelected: (_) => _setTheme(context, t.id),
            ),
          ]),
        ]))),
      ],
      if (profile != null) ...[
        const SizedBox(height: 12),
        // Keyed by profile so switching profiles resets the form.
        _AboutCard(key: ValueKey('about-${profile.id}'), controller: controller),
      ],
      if (controller.isKids) ...[
        const SizedBox(height: 12),
        _KidsSoundCard(controller: controller),
      ],
      if (profile != null && !controller.isKids) ...[
        const SizedBox(height: 12),
        _ProjectsCard(controller: controller),
      ],
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Privacy and guardian controls', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const Text('Do not enter real children\'s personal data until guardian sign-in, verified consent, access controls, security review, privacy notices, and a retention policy are complete.'),
        const SizedBox(height: 9),
        const Text('This app does not infer medical or developmental diagnoses.'),
      ]))),
    ]),
  ));
  }

}

class _IntegrationsPage extends StatelessWidget {
  const _IntegrationsPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Integrations')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850),
      child: ListView(padding: const EdgeInsets.all(22), children: [
        ListTile(leading: const Icon(Icons.storage_outlined), title: const Text('MongoDB Atlas'),
          subtitle: Text(controller.demo ? 'Memory-only demo' : 'Available through the backend API')),
        const ListTile(leading: Icon(Icons.auto_awesome_outlined), title: Text('Gemini Flash'),
          subtitle: Text('Optional highlights, calendar recaps, ideas and writing prompts.')),
        const ListTile(leading: Icon(Icons.mic_none_outlined), title: Text('Voice transcription'),
          subtitle: Text('Transcribes recordings through the configured backend service.')),
      ]))),
  );
}

/// Edits the active profile's optional "About me" details, which personalize
/// the questions on the Today screen and in the entry editor.
class _AboutCard extends StatefulWidget {
  const _AboutCard({super.key, required this.controller});
  final AppController controller;

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  late ProfileDetails _draft = widget.controller.profile?.details ?? ProfileDetails.empty;
  int _formVersion = 0; // bumped to rebuild the form from the saved values
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.controller.setDetails(_draft);
      // Show exactly what the server stored (it may tidy the text), so the
      // form isn't left looking unsaved.
      if (mounted) {
        setState(() {
          _draft = widget.controller.profile?.details ?? _draft;
          _formVersion++;
        });
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.profile;
    final changed = _draft != profile?.details;
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('About ${profile?.name ?? 'this profile'}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(profile?.isKids ?? true
            ? 'Optional. Used only to ask personal questions like "How was school today?". '
                'Prototype: use made-up details, not real ones.'
            : 'Optional. Used only to suggest questions like "How did work go today?" or "Any progress on your goal?". '
                'Prototype: use made-up details, not real ones.'),
        const SizedBox(height: 14),
        ProfileDetailsForm(key: ValueKey(_formVersion), kind: profile?.kind ?? SpaceProfile.kids, initial: _draft,
            onChanged: (d) => setState(() => _draft = d)),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(
          key: const ValueKey('details-save'),
          onPressed: _saving || !changed ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save details'),
        )),
      ],
    )));
  }
}

class _KidsSoundCard extends StatelessWidget {
  const _KidsSoundCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final sound = controller.sound;
    return ListenableBuilder(listenable: sound, builder: (context, _) => Card(child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Commander and music for ${controller.profile?.name ?? 'this profile'}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Kids mode only. The voice is saved per profile; music pauses automatically while recording.'),
        const SizedBox(height: 14),
        const Text('Commander voice', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'f', label: Text('Commander (female)')),
              ButtonSegment(value: 'm', label: Text('Commander (male)')),
            ],
            selected: {controller.voice},
            onSelectionChanged: (v) => controller.setVoice(v.first),
          ),
          TextButton.icon(
            onPressed: () => showCommanderBriefing(context, sound, voice: controller.voice),
            icon: const Icon(Icons.smart_display_outlined),
            label: const Text('Preview video'),
          ),
        ]),
        const SizedBox(height: 16),
        const Text('Background music', style: TextStyle(fontWeight: FontWeight.w600)),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Play music'),
          value: sound.musicOn,
          onChanged: (_) => sound.toggleMusic(),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < SoundService.tracks.length; i++) ChoiceChip(
            label: Text('Track ${i + 1}'),
            selected: sound.trackIndex == i,
            onSelected: (_) => sound.selectTrack(i),
          ),
        ]),
        if (sound.error != null) Padding(padding: const EdgeInsets.only(top: 10),
            child: Text(sound.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ]),
    )));
  }
}

/// Create / select / delete projects for the current (Adult) profile.
class _ProjectsCard extends StatelessWidget {
  const _ProjectsCard({required this.controller});
  final AppController controller;

  void _snack(BuildContext context, Object e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))));
  }

  Future<void> _add(BuildContext context) async {
    final result = await showDialog<String>(context: context, builder: (_) => const _ProjectNameDialog());
    if (result == null || result.trim().isEmpty || !context.mounted) return;
    try { await controller.addProject(result); } catch (e) { if (context.mounted) _snack(context, e); }
  }

  Future<void> _delete(BuildContext context, String id, String name) async {
    final count = controller.entries.where((e) => e.projectId == id).length;
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Delete "$name"?'),
      content: Text(count == 0 ? 'This project has no entries.'
          : 'Its $count ${count == 1 ? 'entry stays' : 'entries stay'} in your journal, without a project.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete project')),
      ],
    ));
    if (yes != true || !context.mounted) return;
    try { await controller.deleteProject(id); } catch (e) { if (context.mounted) _snack(context, e); }
  }

  @override
  Widget build(BuildContext context) {
    final projects = controller.profileProjects;
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Projects', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text('Group entries by project. Selecting one filters the calendar and entries.'),
      const SizedBox(height: 8),
      if (projects.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No projects yet.')),
      for (final p in projects) ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(controller.selectedProjectId == p.id ? Icons.folder : Icons.folder_outlined),
        title: Text(p.name),
        subtitle: Text('${controller.entries.where((e) => e.projectId == p.id).length} entries'),
        selected: controller.selectedProjectId == p.id,
        onTap: () => controller.selectProject(controller.selectedProjectId == p.id ? '' : p.id),
        trailing: IconButton(tooltip: 'Delete project', icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, p.id, p.name)),
      ),
      OutlinedButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.create_new_folder_outlined), label: const Text('New project')),
    ])));
  }
}

/// Owns its text controller so it is disposed only after the dialog (and its
/// exit animation) is gone.
class _ProjectNameDialog extends StatefulWidget {
  const _ProjectNameDialog();
  @override
  State<_ProjectNameDialog> createState() => _ProjectNameDialogState();
}

class _ProjectNameDialogState extends State<_ProjectNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New project'),
        content: TextField(controller: _name, autofocus: true, maxLength: 60,
            decoration: const InputDecoration(labelText: 'Project name'),
            onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _name.text), child: const Text('Create')),
        ],
      );
}
