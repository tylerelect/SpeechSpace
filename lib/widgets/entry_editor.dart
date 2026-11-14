import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/app_controller.dart';
import 'voice_capture.dart';

Future<void> openEntryEditor(BuildContext context, AppController controller,
    {JournalEntry? entry, DateTime? date}) async {
  if (controller.child == null) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .92,
      child: EntryEditor(controller: controller, entry: entry, initialDate: date ?? DateTime.now()),
    ),
  );
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({super.key, required this.controller, required this.initialDate, this.entry});
  final AppController controller;
  final JournalEntry? entry;
  final DateTime initialDate;

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _favorite;
  late final TextEditingController _highlight;
  late final TextEditingController _tags;
  late DateTime _date;
  bool _working = false;
  bool _isMilestone = false;

  @override
  void initState() {
    super.initState();
    _date = widget.entry?.date ?? widget.initialDate;
    _isMilestone = widget.entry?.isMilestone ?? false;
    _title = TextEditingController(text: widget.entry?.title ?? '');
    _body = TextEditingController(text: widget.entry?.body ?? '');
    _favorite = TextEditingController(text: widget.entry?.favorite ?? '');
    _highlight = TextEditingController(text: widget.entry?.highlight ?? '');
    _tags = TextEditingController(text: widget.entry?.tags.join(', ') ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _favorite, _highlight, _tags]) { c.dispose(); }
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _analyze() async {
    if (_body.text.trim().isEmpty) { _message('Add a memory first.'); return; }
    setState(() => _working = true);
    try {
      final result = await widget.controller.analyze(_body.text);
      if (!mounted) return;
      _highlight.text = result.highlight;
      if (result.favorite.isNotEmpty) _favorite.text = result.favorite;
      if (result.tags.isNotEmpty) _tags.text = result.tags.join(', ');
      _message('AI suggestions added. Review and edit before saving.');
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      _message('A title and memory are required.'); return;
    }
    setState(() => _working = true);
    try {
      await widget.controller.saveEntry(JournalEntry(
        id: widget.entry?.id ?? '',
        childId: widget.entry?.childId ?? widget.controller.selectedChildId!,
        date: _date,
        title: _title.text.trim(),
        body: _body.text.trim(),
        favorite: _favorite.text.trim(),
        highlight: _highlight.text.trim(),
        isMilestone: _isMilestone,
        tags: _tags.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(8).toList(),
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete memory?'),
      content: const Text('This removes the memory and its connections. This cannot be undone.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.deleteEntry(entry);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 14),
        child: ListView(children: [
          Row(children: [
            Expanded(child: Text(widget.entry == null ? 'Capture a new chapter' : 'Edit this chapter', style: theme.textTheme.headlineSmall)),
            IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final chosen = await showDatePicker(context: context, initialDate: _date,
                firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)));
              if (chosen != null) setState(() => _date = chosen);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(DateFormat.yMMMMd().format(_date)),
          ),
          const SizedBox(height: 12),
          TextField(controller: _title, maxLength: 100, decoration: const InputDecoration(labelText: 'Memory title', hintText: 'My favorite part of today')),
          VoiceCapture(
            onTranscribe: widget.controller.transcribe,
            onTranscript: (text) {
              _body.text = _body.text.isEmpty ? text : '${_body.text}\n$text';
              _message('Transcript added. You can edit it.');
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: _body, minLines: 5, maxLines: 9, maxLength: 8000,
            decoration: const InputDecoration(labelText: 'What happened?', alignLabelWithHint: true,
              hintText: 'Today I played with…')),
          Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
            onPressed: _working ? null : _analyze,
            icon: const Icon(Icons.auto_awesome_outlined), label: const Text('Suggest highlights with Gemini Flash'),
          )),
          const SizedBox(height: 12),
          TextField(controller: _favorite, decoration: const InputDecoration(labelText: 'Favorite thing (optional)')),
          const SizedBox(height: 12),
          TextField(controller: _highlight, maxLines: 2, decoration: const InputDecoration(labelText: 'Short highlight (optional)')),
          const SizedBox(height: 12),
          TextField(controller: _tags, decoration: const InputDecoration(labelText: 'Tags (comma-separated)', hintText: 'Family, Outdoors, Learning')),
          SwitchListTile.adaptive(
            title: const Text('Mark as a milestone'),
            subtitle: const Text('Guardian-selected memory; never an AI developmental assessment.'),
            value: _isMilestone,
            onChanged: (value) => setState(() => _isMilestone = value),
          ),
          const SizedBox(height: 14),
          const Text('A parent or guardian should review every AI-generated suggestion. This is a memory journal, not a developmental assessment.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          Row(children: [
            if (widget.entry != null) IconButton(tooltip: 'Delete memory', onPressed: _working ? null : _delete, icon: const Icon(Icons.delete_outline)),
            const Spacer(),
            FilledButton.icon(onPressed: _working ? null : _save,
              icon: const Icon(Icons.save_outlined), label: Text(_working ? 'Saving…' : 'Save memory')),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    ));
  }
}
