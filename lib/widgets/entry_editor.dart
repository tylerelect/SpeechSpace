import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/app_controller.dart';
import '../services/profile_questions.dart';
import '../services/writing_prompts.dart';
import 'voice_capture.dart';

/// Opens the editor. For a new entry, [suggestion] pre-fills the title and shows
/// the idea as guidance; [onSaved] receives the saved entry.
Future<void> openEntryEditor(BuildContext context, AppController controller,
    {JournalEntry? entry, DateTime? date, StarIdea? suggestion, ValueChanged<JournalEntry>? onSaved}) async {
  if (controller.profile == null) return;
  // A full-screen page (not a sheet) so it can't be swiped away mid-story: it
  // closes only through the Close button, Save/Delete, or a confirmed back.
  await Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => EntryEditor(controller: controller, entry: entry, initialDate: date ?? DateTime.now(),
        suggestion: suggestion, onSaved: onSaved),
  ));
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({super.key, required this.controller, required this.initialDate, this.entry,
      this.suggestion, this.onSaved, this.voiceRecorderFactory});
  final AppController controller;
  /// Test hook for the microphone; defaults to the real recorder.
  final VoiceRecorder Function()? voiceRecorderFactory;
  final StarIdea? suggestion;
  final ValueChanged<JournalEntry>? onSaved;
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
  String _projectId = '';
  final _bodyFocus = FocusNode();
  final _scroll = ScrollController();
  final Set<String> _usedPrompts = {};
  late final String _initialState;

  String _stateKey() => [_title.text, _body.text, _favorite.text, _highlight.text, _tags.text,
      _date.toIso8601String(), _isMilestone, _projectId].join('\u0000');
  bool get _dirty => _stateKey() != _initialState;

  /// Close button / system back: leave right away if nothing changed, else confirm.
  Future<void> _requestClose() async {
    if (_working) return;
    if (!_dirty) { Navigator.of(context).pop(); return; }
    final kids = widget.controller.copy.isKids;
    final discard = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(kids ? 'Leave without saving?' : 'Discard changes?'),
      content: Text(kids ? 'Your story is not saved yet.' : 'Your changes to this entry are not saved.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
      ],
    ));
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final chosen = await showDatePicker(context: context, initialDate: _date,
      firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (chosen != null) setState(() => _date = chosen);
  }

  @override
  void initState() {
    super.initState();
    _date = widget.entry?.date ?? widget.initialDate;
    _isMilestone = widget.entry?.isMilestone ?? false;
    // New entries default to the project currently being viewed.
    _projectId = widget.entry?.projectId ?? widget.controller.selectedProjectId;
    _title = TextEditingController(text: widget.entry?.title ?? widget.suggestion?.title ?? '');
    _body = TextEditingController(text: widget.entry?.body ?? '');
    _favorite = TextEditingController(text: widget.entry?.favorite ?? '');
    _highlight = TextEditingController(text: widget.entry?.highlight ?? '');
    _tags = TextEditingController(text: widget.entry?.tags.join(', ') ?? '');
    _body.addListener(_onBodyChanged);
    _initialState = _stateKey();
  }

  // Rebuild only when the suggestion chips would change, not on every keystroke.
  List<String> _shownPromptIds = const [];
  bool _waiting = true;
  void _onBodyChanged() {
    final ids = _prompts.map((p) => p.id).toList();
    final waiting = _wordsNeeded > 0;
    if (ids.join() != _shownPromptIds.join() || waiting != _waiting) {
      setState(() { _shownPromptIds = ids; _waiting = waiting; });
    }
    if (_geminiOn) {
      _geminiDebounce?.cancel();
      _geminiDebounce = Timer(_geminiPause, _refreshGemini);
    }
  }

  static final _word = RegExp(r"[A-Za-z']+");
  static int _countWords(String text) => _word.allMatches(text).length;

  int get _wordsNeeded {
    final count = _countWords(_body.text);
    return count >= promptMinWords ? 0 : promptMinWords - count;
  }

  /// Gemini chips first, then local keyword chips to fill the remaining slots.
  List<WritingPrompt> get _prompts {
    final ai = _geminiPrompts.where((p) => !_usedPrompts.contains(p.id)).toList();
    final local = suggestPrompts(_body.text, kids: widget.controller.isKids, used: _usedPrompts);
    final labels = ai.map((p) => p.label.toLowerCase()).toSet();
    return [...ai, ...local.where((p) => !labels.contains(p.label.toLowerCase()))].take(4).toList();
  }

  void _usePrompt(WritingPrompt prompt) {
    final text = appendStarter(_body.text, prompt.starter);
    _usedPrompts.add(prompt.id);
    _body.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    _bodyFocus.requestFocus();
    setState(() {});
  }

  // ---- Gemini suggestions -------------------------------------------------
  // Off until the writer taps "Ask Gemini" for this entry (nothing is sent before
  // that). Then refreshes after a pause in typing, once a few words have changed.
  static const _geminiPause = Duration(milliseconds: 1500);
  static const _geminiMinNewWords = 3;
  bool _geminiOn = false;
  bool _geminiLoading = false;
  String? _geminiError;
  List<WritingPrompt> _geminiPrompts = const [];
  Timer? _geminiDebounce;
  int _geminiSentWords = 0;
  String _geminiSentText = '';
  int _geminiRequest = 0;

  void _askGemini() {
    setState(() { _geminiOn = true; _geminiError = null; });
    _refreshGemini(force: true);
  }

  Future<void> _refreshGemini({bool force = false}) async {
    final text = _body.text.trim();
    final words = _countWords(text);
    if (!mounted || words < promptMinWords || text == _geminiSentText) return;
    if (!force && (words - _geminiSentWords).abs() < _geminiMinNewWords) return;
    _geminiSentText = text;
    _geminiSentWords = words;
    final request = ++_geminiRequest;
    setState(() => _geminiLoading = true);
    try {
      final prompts = await widget.controller.detailPrompts(text);
      if (!mounted || request != _geminiRequest) return; // a newer request superseded this one
      setState(() { _geminiPrompts = prompts; _geminiError = null; _shownPromptIds = _prompts.map((p) => p.id).toList(); });
    } catch (error) {
      if (!mounted || request != _geminiRequest) return;
      setState(() => _geminiError = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted && request == _geminiRequest) setState(() => _geminiLoading = false);
    }
  }

  @override
  void dispose() {
    _geminiDebounce?.cancel();
    _body.removeListener(_onBodyChanged);
    _bodyFocus.dispose();
    _scroll.dispose();
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
      final saved = await widget.controller.saveEntry(JournalEntry(
        id: widget.entry?.id ?? '',
        childId: widget.entry?.childId ?? widget.controller.selectedProfileId!,
        date: _date,
        title: _title.text.trim(),
        body: _body.text.trim(),
        favorite: _favorite.text.trim(),
        highlight: _highlight.text.trim(),
        isMilestone: _isMilestone,
        projectId: _projectId,
        tags: _tags.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(8).toList(),
      ));
      widget.onSaved?.call(saved);
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
    final copy = widget.controller.copy;
    return PopScope(
      canPop: false, // system/Android back goes through the unsaved-changes check
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _requestClose(); },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Close', onPressed: _working ? null : _requestClose, icon: const Icon(Icons.close)),
          title: Text(widget.entry == null ? copy.editorNewTitle : copy.editorEditTitle),
          actions: [
            TextButton(onPressed: _working ? null : _save, child: Text(_working ? 'Saving…' : 'Save')),
            PopupMenuButton<String>(
              tooltip: 'More options',
              enabled: !_working,
              onSelected: (value) {
                switch (value) {
                  case 'date': _pickDate();
                  case 'highlights': _analyze();
                  case 'milestone': setState(() => _isMilestone = !_isMilestone);
                  case 'delete': _delete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'date', child: ListTile(leading: Icon(Icons.calendar_today_outlined), title: Text('Change date'))),
                const PopupMenuItem(value: 'highlights', child: ListTile(leading: Icon(Icons.auto_awesome_outlined), title: Text('Suggest highlights'))),
                PopupMenuItem(value: 'milestone', child: ListTile(leading: Icon(_isMilestone ? Icons.flag : Icons.flag_outlined),
                    title: Text(_isMilestone ? 'Unmark milestone' : 'Mark as milestone'))),
                if (widget.entry != null) const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
              ],
            ),
          ],
        ),
        // The page scrolls with a scrollbar that's always visible, so it's clear there's more below.
        body: SafeArea(top: false, child: Scrollbar(controller: _scroll, thumbVisibility: true, child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(DateFormat.yMMMMd().format(_date)),
          )),
          const SizedBox(height: 12),
          if (widget.suggestion != null) Card(
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: Icon(Icons.tips_and_updates_outlined, color: theme.colorScheme.onSecondaryContainer),
              title: Text(widget.suggestion!.detail.isEmpty ? widget.suggestion!.title : widget.suggestion!.detail,
                  style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
              subtitle: Text(copy.isKids ? 'Idea to get you started. Tell it in your own words!'
                  : 'Suggestion to get you started. Write it in your own words.',
                  style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
            ),
          ),
          if (widget.suggestion != null) const SizedBox(height: 12),
          TextField(controller: _title, maxLength: 100, decoration: InputDecoration(labelText: copy.titleLabel, hintText: copy.titleHint)),
          VoiceCapture(
            onTranscribe: widget.controller.transcribe,
            recorderFactory: widget.voiceRecorderFactory,
            prompt: copy.recordPrompt,
            onRecordingChanged: widget.controller.sound.onRecordingChanged,
            onTranscript: (text) {
              _body.text = _body.text.isEmpty ? text : '${_body.text}\n$text';
              _message('Transcript added. You can edit it.');
            },
          ),
          // Questions are worded for today ("How was school today?"), so they're
          // only offered for today's entries, not back-dated ones.
          if (DateUtils.isSameDay(_date, DateTime.now())) _ProfileQuestions(
            prompts: startingPrompts(widget.controller.profile, _date, used: _usedPrompts),
            kids: copy.isKids, onTap: _usePrompt),
          const SizedBox(height: 12),
          TextField(controller: _body, focusNode: _bodyFocus, minLines: 5, maxLines: 9, maxLength: 8000,
            decoration: InputDecoration(labelText: copy.bodyLabel, alignLabelWithHint: true,
              hintText: copy.bodyHint)),
          _DetailPrompts(prompts: _prompts, kids: copy.isKids, wordsNeeded: _wordsNeeded, onTap: _usePrompt,
              geminiOn: _geminiOn, geminiLoading: _geminiLoading, geminiError: _geminiError,
              demo: widget.controller.demo, onAskGemini: _askGemini,
              onRefreshGemini: () => _refreshGemini(force: true)),
          const SizedBox(height: 8),
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
          if (widget.controller.profileProjects.isNotEmpty || _projectId.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<String>(
              initialValue: widget.controller.profileProjects.any((p) => p.id == _projectId) ? _projectId : '',
              decoration: const InputDecoration(labelText: 'Project (optional)', prefixIcon: Icon(Icons.folder_outlined)),
              items: [
                const DropdownMenuItem(value: '', child: Text('No project')),
                for (final p in widget.controller.profileProjects) DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _projectId = v ?? ''),
            ),
          ),
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
              icon: const Icon(Icons.save_outlined), label: Text(_working ? 'Saving…' : copy.saveLabel)),
          ]),
          const SizedBox(height: 20),
          ])))],
        ))),
      ),
    );
  }
}

/// Conversation starters from the profile's "About me" details ("How was
/// school today?"). Shown even before anything is written, since they're meant
/// to help get started. Hidden when the profile has none to offer.
class _ProfileQuestions extends StatelessWidget {
  const _ProfileQuestions({required this.prompts, required this.kids, required this.onTap});
  final List<WritingPrompt> prompts;
  final bool kids;
  final ValueChanged<WritingPrompt> onTap;

  @override
  Widget build(BuildContext context) {
    if (prompts.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(top: 12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(kids ? 'Need an idea?' : 'Starting points', style: TextStyle(fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in prompts) ActionChip(
            key: ValueKey('question-${p.id}'),
            avatar: Icon(p.icon, size: kids ? 20 : 18, color: scheme.primary),
            label: Text(p.label, style: kids ? const TextStyle(fontSize: 15) : null),
            padding: kids ? const EdgeInsets.symmetric(horizontal: 6, vertical: 8) : null,
            onPressed: () => onTap(p),
          ),
        ]),
      ],
    ));
  }
}

/// "Add more details" chips under the note. Hidden until there's a starter sentence.
/// Gemini chips are marked with a sparkle; local keyword chips use plain icons.
class _DetailPrompts extends StatelessWidget {
  const _DetailPrompts({required this.prompts, required this.kids, required this.wordsNeeded, required this.onTap,
      required this.geminiOn, required this.geminiLoading, required this.geminiError, required this.demo,
      required this.onAskGemini, required this.onRefreshGemini});
  final List<WritingPrompt> prompts;
  final bool kids;
  final int wordsNeeded;
  final ValueChanged<WritingPrompt> onTap;
  final bool geminiOn;
  final bool geminiLoading;
  final String? geminiError;
  final bool demo;
  final VoidCallback onAskGemini;
  final VoidCallback onRefreshGemini;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    if (wordsNeeded > 0) {
      return Text(kids ? 'Write a little to get story helpers ✨' : 'Write a sentence to get detail suggestions.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted));
    }
    final chipPadding = kids ? const EdgeInsets.symmetric(horizontal: 6, vertical: 8) : null;
    final chipText = kids ? const TextStyle(fontSize: 15) : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(kids ? 'Add more to your story' : 'Add more details',
            style: theme.textTheme.labelLarge?.copyWith(color: muted)),
        if (geminiOn) ...[
          const SizedBox(width: 8),
          if (geminiLoading)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(visualDensity: VisualDensity.compact, iconSize: 18, tooltip: 'Refresh Gemini suggestions',
                onPressed: onRefreshGemini, icon: const Icon(Icons.refresh)),
          Text(demo ? 'Demo samples (not Gemini)' : 'Gemini suggestions on',
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in prompts) ActionChip(
          avatar: Icon(p.icon, size: kids ? 20 : 18, color: p.fromAi ? scheme.tertiary : null),
          label: Text(p.label, style: chipText),
          backgroundColor: p.fromAi ? scheme.tertiaryContainer.withValues(alpha: .5) : null,
          padding: chipPadding,
          tooltip: 'Adds "${p.starter.trim()}…" to your note',
          onPressed: () => onTap(p),
        ),
        if (!geminiOn) ActionChip(
          avatar: Icon(Icons.auto_awesome, size: kids ? 20 : 18, color: scheme.tertiary),
          label: Text(kids ? 'More ideas from Gemini' : 'Ask Gemini', style: chipText),
          padding: chipPadding,
          tooltip: 'Sends this draft to Gemini (through your backend) for suggestions that fit what you wrote',
          onPressed: onAskGemini,
        ),
      ]),
      if (geminiError != null) Padding(padding: const EdgeInsets.only(top: 6),
          child: Text('Gemini suggestions unavailable: $geminiError. The other suggestions still work.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error))),
    ]);
  }
}
