import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeData;

import '../models/models.dart';
import '../theme/mode_copy.dart';
import '../theme/space_themes.dart';
import 'repository.dart';
import 'sound_service.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository, {SoundService? sound}) : sound = sound ?? SoundService();
  final MemoryRepository repository;
  final SoundService sound;

  bool loading = true;
  String? loadError;
  List<SpaceProfile> profiles = [];
  List<JournalEntry> entries = [];
  List<MemoryLink> links = [];
  String? selectedProfileId;

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

  /// Only the active profile's data is ever exposed to screens.
  List<JournalEntry> get profileEntries => entries.where((e) => e.childId == selectedProfileId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
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
    try {
      await refresh();
      loadError = null;
    } catch (error) {
      loadError = error.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final data = await repository.load();
    profiles = data.children;
    entries = data.entries;
    links = data.links;
    if (selectedProfileId == null || !profiles.any((p) => p.id == selectedProfileId)) {
      selectedProfileId = profiles.isEmpty ? null : profiles.first.id;
      sound.onProfileKindChanged(isKids);
    }
    notifyListeners();
  }

  void selectProfile(String id) {
    if (id == selectedProfileId) return;
    selectedProfileId = id;
    sound.selectVoice(voice);
    sound.onProfileKindChanged(isKids);
    notifyListeners();
  }

  /// Opens the app for [id] (or the current profile) from the start screen.
  void enterApp([String? id]) {
    if (id != null) selectProfile(id);
    if (profile == null) return;
    started = true;
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> deleteCurrentProfile() async {
    if (selectedProfileId == null) return;
    await repository.deleteChild(selectedProfileId!);
    await refresh();
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
      if (source == saved.id || !entries.any((e) => e.id == source)) continue;
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

  @override
  void dispose() {
    sound.dispose();
    super.dispose();
  }
}
