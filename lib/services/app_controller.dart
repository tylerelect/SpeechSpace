import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeData;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar.dart';
import '../models/models.dart';
import '../theme/mode_copy.dart';
import '../theme/space_themes.dart';
import 'layout_store.dart';
import 'repository.dart';
import 'sound_service.dart';
import 'writing_prompts.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository, {SoundService? sound, this.persistSelection = true,
    Future<SharedPreferences> Function()? preferencesLoader})
      : sound = sound ?? SoundService(),
        _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _preferencesLoader;
  static const _selectionTimeout = Duration(seconds: 2);
  final MemoryRepository repository;
  final SoundService sound;
  /// Remembers the selected profile across restarts (convenience, not auth).
  final bool persistSelection;
  static const selectedProfileKey = 'selectedProfileId';

  bool loading = true;
  String? loadError;
  List<SpaceProfile> profiles = [];
  List<JournalEntry> entries = [];
  List<MemoryLink> links = [];
  List<ProjectSpace> projects = [];
  String? selectedProfileId;
  /// '' = all entries; otherwise only entries in this project.
  String selectedProjectId = '';

  /// Calendar navigation lives here (not in the widget) so it is predictable
  /// across tabs and so other screens (e.g. Activity) can open a given day.
  CalendarView calendarView = CalendarView.month;
  DateTime calendarDate = _today();
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Guards [refresh] against an older, slower snapshot overwriting a newer one.
  int _loadSeq = 0;

  /// Bumped whenever data or the selection changes, so screens holding fetched
  /// data (e.g. the calendar) know to reload instead of showing stale results.
  int revision = 0;

  /// False while the start screen ("Who's using SpeechSpace?") is showing.
  bool started = false;

  /// Commander voice per profile ('f' or 'm'). Local only: the API contract has
  /// no voice field, so this resets on restart like the other sound settings.
  final Map<String, String> profileVoices = {};
  String get voice => profileVoices[selectedProfileId] ?? 'f';

  bool get demo => repository.isDemo;
  SpaceProfile? get profile {
    for (final p in profiles) { if (p.id == selectedProfileId) return p; }
    return null;
  }

  bool get isKids => profile?.isKids ?? false;
  String get kind => profile?.kind ?? SpaceProfile.adult;
  ModeCopy get copy => ModeCopy.forKind(kind);
  SpaceTheme get spaceTheme => resolveTheme(profile?.themeId, kind);
  ThemeData get theme => buildTheme(spaceTheme);

  /// Only the active profile's data (and selected project, if any) is exposed to screens.
  List<JournalEntry> get profileEntries => entries
      .where((e) => e.childId == selectedProfileId && (selectedProjectId.isEmpty || e.projectId == selectedProjectId))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  List<ProjectSpace> get profileProjects => projects.where((p) => p.profileId == selectedProfileId).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  ProjectSpace? get selectedProject {
    for (final p in profileProjects) { if (p.id == selectedProjectId) return p; }
    return null;
  }
  List<MemoryLink> get profileLinks => links.where((l) => l.childId == selectedProfileId).toList();

  /// Gemini star suggestions. Session-only, never sent to storage.
  final List<StarIdea> ideas = [];
  bool generatingIdeas = false;
  List<StarIdea> get profileIdeas {
    final ids = profileEntries.map((e) => e.id).toSet();
    return ideas.where((i) => i.profileId == selectedProfileId && i.sourceIds.any(ids.contains)).toList();
  }

  Future<void> initialize() async {
    loading = true;
    notifyListeners();
    // Optional device storage and the API can load concurrently. A stalled
    // preferences plugin must not hold the app on its loading screen forever.
    final preferences = _startupPreferences();
    try {
      await refresh();
      await _restoreSelection(preferences);
      loadError = null;
    } catch (error) {
      loadError = error.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() {
    final seq = ++_loadSeq;
    return _latestRefresh = _refresh(seq);
  }

  Future<void>? _latestRefresh;

  Future<void> _refresh(int seq) async {
    final data = await repository.load();
    if (seq != _loadSeq) {
      // A newer refresh started while this one was in flight: drop this
      // (possibly stale) snapshot and wait for the newest one instead.
      await _latestRefresh;
      return;
    }
    profiles = data.children;
    entries = data.entries;
    links = data.links;
    projects = data.projects;
    if (selectedProfileId == null || !profiles.any((p) => p.id == selectedProfileId)) {
      selectedProfileId = profiles.isEmpty ? null : profiles.first.id;
      selectedProjectId = '';
      _resetCalendar();
      sound.onProfileKindChanged(isKids);
    }
    if (selectedProjectId.isNotEmpty && !profileProjects.any((p) => p.id == selectedProjectId)) selectedProjectId = '';
    revision++;
    notifyListeners();
  }

  /// Restores the remembered profile only if it still exists; otherwise keeps
  /// the fallback chosen by [refresh] and shows the start screen.
  Future<SharedPreferences?> _startupPreferences() async {
    if (!persistSelection) return null;
    try {
      return await _preferencesLoader().timeout(_selectionTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreSelection(Future<SharedPreferences?> preferences) async {
    try {
      final prefs = await preferences;
      if (prefs == null) return;
      final saved = prefs.getString(selectedProfileKey);
      if (saved != null && profiles.any((p) => p.id == saved)) {
        selectProfile(saved);
        started = true;
      } else if (saved != null) {
        // Best-effort cleanup must not delay startup either.
        unawaited(prefs.remove(selectedProfileKey).catchError((_) => false));
      }
    } catch (_) {
      // Storage unavailable: carry on without persistence.
    }
  }

  Future<void> _saveSelection() async {
    if (!persistSelection) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = selectedProfileId;
      if (id == null) { await prefs.remove(selectedProfileKey); } else { await prefs.setString(selectedProfileKey, id); }
    } catch (_) {}
  }

  void selectProfile(String id) {
    if (id == selectedProfileId) return;
    selectedProfileId = id;
    selectedProjectId = ''; // projects belong to one profile
    _resetCalendar(); // calendar state is per profile; never carry it over
    sound.selectVoice(voice);
    sound.onProfileKindChanged(isKids);
    revision++;
    notifyListeners();
    _saveSelection();
  }

  void _resetCalendar() {
    calendarView = CalendarView.month;
    calendarDate = _today();
  }

  /// Moves the calendar to [view] around [date] (e.g. a heat-map drilldown).
  void setCalendar(CalendarView view, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (view == calendarView && day == calendarDate) return;
    calendarView = view;
    calendarDate = day;
    notifyListeners();
  }

  /// Project filter for calendar requests: Kids profiles are always scoped to
  /// the whole profile; Adults may narrow to one project.
  String get calendarProjectId => isKids ? '' : selectedProjectId;

  void selectProject(String id) {
    if (id.isNotEmpty && !profileProjects.any((p) => p.id == id)) return;
    if (id == selectedProjectId) return;
    selectedProjectId = id;
    revision++;
    notifyListeners();
  }

  Future<ProjectSpace> addProject(String name) async {
    final id = selectedProfileId;
    final trimmed = name.trim();
    if (id == null) throw StateError('Choose a profile first.');
    if (trimmed.isEmpty) throw StateError('A project name is required.');
    final created = await repository.addProject(id, trimmed);
    await refresh();
    return created;
  }

  /// Entries in the project survive and become unassigned.
  Future<void> deleteProject(String id) async {
    await repository.deleteProject(id);
    if (selectedProjectId == id) selectedProjectId = '';
    await refresh();
  }

  /// Opens the app for [id] (or the current profile) from the start screen.
  void enterApp([String? id]) {
    if (id != null) selectProfile(id);
    if (profile == null) return;
    started = true;
    notifyListeners();
    _saveSelection();
  }

  /// Back to the start screen. Stops any sound so the chooser is quiet.
  Future<void> switchUser() async {
    started = false;
    notifyListeners();
    await sound.stopBriefing();
    await sound.stopMusic();
  }

  void setVoice(String id) {
    final current = selectedProfileId;
    if (current == null) return;
    profileVoices[current] = id;
    sound.selectVoice(id);
    notifyListeners();
  }

  /// Creates a profile with the choices from the setup flow and selects it.
  Future<SpaceProfile> addProfile(String name, String kind, {String? themeId, String? voice}) async {
    var created = await repository.addProfile(name.trim(), kind);
    if (themeId != null && themeId != created.themeId) {
      created = await repository.updateProfile(created.copyWith(themeId: themeId));
    }
    if (voice != null) profileVoices[created.id] = voice;
    await refresh();
    selectProfile(created.id);
    return created;
  }

  Future<void> setTheme(String themeId) async {
    final current = profile;
    if (current == null || current.themeId == themeId) return;
    final saved = await repository.updateProfile(current.copyWith(themeId: themeId));
    profiles = [for (final p in profiles) p.id == saved.id ? saved : p];
    revision++;
    notifyListeners();
  }

  Future<void> deleteCurrentProfile() async {
    final id = selectedProfileId;
    if (id == null) return;
    await repository.deleteChild(id);
    if (persistSelection) await MindMapLayoutStore.clear(id);
    selectedProjectId = '';
    await refresh();
    await _saveSelection();
    if (profiles.isEmpty) { started = false; notifyListeners(); }
  }

  Future<JournalEntry> saveEntry(JournalEntry entry) async {
    final saved = await repository.saveEntry(entry);
    await refresh();
    return saved;
  }

  /// Asks Gemini (via the backend) for new stars based on 1–6 related entries.
  /// Returns how many suggestions were added.
  Future<int> generateIdeas(List<String> entryIds) async {
    final profileId = selectedProfileId;
    if (profileId == null) throw StateError('Choose a profile first.');
    final own = profileEntries.map((e) => e.id).toSet();
    final picked = entryIds.where(own.contains).toSet().toList();
    if (picked.isEmpty) throw StateError('Choose at least one entry.');
    if (picked.length > 6) throw StateError('Choose up to 6 entries.');
    generatingIdeas = true;
    notifyListeners();
    try {
      final result = await repository.expand(profileId, picked, kind: kind);
      // Ignore results if the user switched profile while waiting.
      final valid = result.where((i) => i.profileId == profileId && i.sourceIds.every(own.contains)).toList();
      ideas.addAll(valid);
      return valid.length;
    } finally {
      generatingIdeas = false;
      notifyListeners();
    }
  }

  void dismissIdea(String id) {
    ideas.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  /// After the user saves a suggestion as a real entry, link it to the stars it
  /// came from and remove the suggestion.
  Future<void> acceptIdea(StarIdea idea, JournalEntry saved) async {
    ideas.removeWhere((i) => i.id == idea.id);
    final label = idea.isRecommendation ? 'recommended' : 'idea';
    for (final source in idea.sourceIds) {
      // Only link to entries that still exist in the same profile.
      if (source == saved.id || !entries.any((e) => e.id == source && e.childId == saved.childId)) continue;
      await repository.addLink(MemoryLink(id: '', childId: saved.childId, fromId: source, toId: saved.id, label: label));
    }
    await refresh();
  }

  Future<void> deleteEntry(JournalEntry entry) async {
    await repository.deleteEntry(entry.id);
    await refresh();
  }

  Future<void> addLink(String from, String to, String label) async {
    if (from == to || selectedProfileId == null) throw StateError('Choose two different memories.');
    if (profileLinks.any((l) => (l.fromId == from && l.toId == to) || (l.fromId == to && l.toId == from))) {
      throw StateError('These memories are already connected.');
    }
    await repository.addLink(MemoryLink(id: '', childId: selectedProfileId!, fromId: from, toId: to, label: label));
    await refresh();
  }

  Future<void> removeLink(String id) async {
    await repository.deleteLink(id);
    await refresh();
  }

  Future<AiInsight> analyze(String text) => repository.analyze(text, kind: kind);
  Future<String> transcribe(Uint8List wav) => repository.transcribe(wav);

  /// Calendar data for the active profile (and selected project).
  Future<CalendarData> calendar(CalendarView view, DateTime date) {
    final id = selectedProfileId;
    if (id == null) return Future.error(StateError('Choose a profile first.'));
    return repository.calendar(id, view, date, projectId: calendarProjectId);
  }

  /// On-demand recap; only called when the user taps Generate summary.
  Future<CalendarSummary> calendarSummary(CalendarView view, DateTime date) {
    final id = selectedProfileId;
    if (id == null) return Future.error(StateError('Choose a profile first.'));
    return repository.calendarSummary(id, view, date, projectId: calendarProjectId);
  }
  Future<List<WritingPrompt>> detailPrompts(String text) => repository.detailPrompts(text, kind: kind);

  @override
  void dispose() {
    sound.dispose();
    super.dispose();
  }
}
