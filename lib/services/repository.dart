import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/calendar.dart';
import '../models/models.dart';
import 'writing_prompts.dart';

abstract class MemoryRepository {
  bool get isDemo;
  Future<AppSnapshot> load();
  Future<SpaceProfile> addProfile(String name, String kind);
  /// Saves [profile]'s theme and/or details. Only the selected parts are sent,
  /// so a theme change can't overwrite details saved elsewhere (or vice versa).
  Future<SpaceProfile> updateProfile(SpaceProfile profile, {bool theme = true, bool details = true});
  Future<void> deleteChild(String id); // deletes any profile (Kids or Adult)
  Future<ProjectSpace> addProject(String profileId, String name);
  /// Deletes a project; its entries survive with `projectId: ''`.
  Future<void> deleteProject(String id);
  Future<JournalEntry> saveEntry(JournalEntry entry);
  Future<void> deleteEntry(String id);
  Future<MemoryLink> addLink(MemoryLink link);
  Future<void> deleteLink(String id);
  Future<AiInsight> analyze(String text, {required String kind});
  /// Asks Gemini for new ideas/recommendations based on related entries.
  Future<List<StarIdea>> expand(String profileId, List<String> entryIds, {required String kind});
  /// Asks Gemini for "add more detail" prompts that fit the draft being written.
  /// [profileId], when given, lets the backend tailor prompts to that
  /// profile's optional "About me" details.
  Future<List<WritingPrompt>> detailPrompts(String text, {required String kind, String? profileId});
  Future<String> transcribe(Uint8List wav);
  Future<CalendarData> calendar(String profileId, CalendarView view, DateTime date, {String projectId = ''});
  /// Generates a recap on demand. Never saved.
  Future<CalendarSummary> calendarSummary(String profileId, CalendarView view, DateTime date, {String projectId = ''});
}

/// A backend error with its HTTP status, so the UI can explain what went wrong.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
int _nextId = 0;

/// In-memory synthetic sample data (one Kids and one Adult profile).
/// Nothing is persisted: all changes are lost on restart.
class DemoRepository implements MemoryRepository {
  @override
  bool get isDemo => true;
  final List<SpaceProfile> _children = [
    const SpaceProfile(id: 'demo-alex', name: 'Alex', details: ProfileDetails(
        age: 8, school: 'Maple School', favoriteColor: 'Blue', interests: ['dinosaurs', 'soccer'])),
    const SpaceProfile(id: 'demo-jordan', name: 'Jordan', kind: SpaceProfile.adult, details: ProfileDetails(
        age: 34, occupation: 'Designer', goals: ['run a 10k'], interests: ['cooking'])),
  ];
  final List<JournalEntry> _entries = [];
  final List<MemoryLink> _links = [];
  final List<ProjectSpace> _projects = [
    const ProjectSpace(id: 'demo-project-home', profileId: 'demo-jordan', name: 'Home'),
    const ProjectSpace(id: 'demo-project-fitness', profileId: 'demo-jordan', name: 'Fitness'),
  ];

  DemoRepository() {
    final today = DateTime.now();
    _entries.addAll([
      JournalEntry(id: 'demo-1', childId: 'demo-alex', date: today.subtract(const Duration(days: 1)), title: 'The big blue kite',
          body: 'Today we went outside. My favorite part was flying a big blue kite with Grandpa!', favorite: 'Blue kite',
          highlight: 'A happy afternoon flying a kite.', tags: const ['Outdoors', 'Family']),
      JournalEntry(id: 'demo-2', childId: 'demo-alex', date: today.subtract(const Duration(days: 4)), title: 'Favorite outfit',
          body: 'I wore my yellow raincoat because it has little ducks on it.', favorite: 'Yellow raincoat',
          highlight: 'Alex chose a favorite outfit.', tags: const ['Favorites']),
      JournalEntry(id: 'demo-3', childId: 'demo-alex', date: today.subtract(const Duration(days: 9)), title: 'Made a cardboard castle',
          body: 'We made a castle from boxes and drew windows and a drawbridge.',
          highlight: 'A creative day building a cardboard castle.', tags: const ['Creativity', 'Family']),
      JournalEntry(id: 'demo-a1', childId: 'demo-jordan', date: today, title: 'Planning the week',
          body: 'Blocked out time for the garden project and booked the dentist for Thursday.',
          highlight: 'Weekly plan set.', tags: const ['Planning']),
      JournalEntry(id: 'demo-a2', childId: 'demo-jordan', date: today.subtract(const Duration(days: 2)), title: 'Started a running routine',
          body: 'First 3k run in a while. Felt slow but finished it.', isMilestone: true,
          highlight: 'First run of the new routine.', tags: const ['Health', 'Goals']),
    ]);
    _links.addAll(const [
      MemoryLink(id: 'demo-link', childId: 'demo-alex', fromId: 'demo-1', toId: 'demo-3', label: 'Family activities'),
      MemoryLink(id: 'demo-link-a', childId: 'demo-jordan', fromId: 'demo-a1', toId: 'demo-a2', label: 'Goals'),
    ]);
  }

  @override
  Future<AppSnapshot> load() async => AppSnapshot(children: List.of(_children), entries: List.of(_entries),
      links: List.of(_links), projects: List.of(_projects));

  @override
  Future<ProjectSpace> addProject(String profileId, String name) async {
    if (!_children.any((c) => c.id == profileId)) throw StateError('Profile not found.');
    final project = ProjectSpace(id: newId(), profileId: profileId, name: name.trim());
    _projects.add(project);
    return project;
  }

  @override
  Future<void> deleteProject(String id) async {
    _projects.removeWhere((p) => p.id == id);
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].projectId == id) _entries[i] = _entries[i].copyWith(projectId: '');
    }
  }

  @override
  Future<CalendarData> calendar(String profileId, CalendarView view, DateTime date, {String projectId = ''}) async =>
      CalendarData.compute(profileId: profileId, view: view, date: date, projectId: projectId, allEntries: _entries);

  /// Offline recap built only from recorded fields, marked as a demo sample.
  @override
  Future<CalendarSummary> calendarSummary(String profileId, CalendarView view, DateTime date, {String projectId = ''}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final data = CalendarData.compute(profileId: profileId, view: view, date: date, projectId: projectId, allEntries: _entries);
    if (data.entryCount == 0) {
      return CalendarSummary(period: data.period, entryCount: 0, activeDays: 0, milestoneCount: 0, generated: false,
          partial: false, analyzedEntries: 0, summary: 'No entries recorded for this ${view.wire}.',
          highlights: const [], themes: const [], milestones: const [], demo: true);
    }
    final analyzed = data.entries.take(maxSummaryEntries).toList();
    final tagCounts = <String, int>{};
    for (final e in analyzed) { for (final t in e.tags) { tagCounts[t] = (tagCounts[t] ?? 0) + 1; } }
    final themes = (tagCounts.keys.toList()..sort((a, b) => tagCounts[b]!.compareTo(tagCounts[a]!))).take(4).toList();
    return CalendarSummary(
      period: data.period, entryCount: data.entryCount, activeDays: data.activeDays, milestoneCount: data.milestoneCount,
      generated: true, partial: analyzed.length < data.entryCount, analyzedEntries: analyzed.length,
      summary: '${data.entryCount} ${data.entryCount == 1 ? 'entry' : 'entries'} recorded across '
          '${data.activeDays} ${data.activeDays == 1 ? 'day' : 'days'}.',
      highlights: analyzed.take(3).map((e) => e.highlight.isNotEmpty ? e.highlight : e.title).toList(),
      themes: themes,
      milestones: analyzed.where((e) => e.isMilestone).map((e) => e.title).toList(),
      sourceEntryIds: analyzed.map((e) => e.id).toList(),
      demo: true,
    );
  }

  @override
  Future<SpaceProfile> addProfile(String name, String kind) async {
    final profile = SpaceProfile(id: newId(), name: name, kind: kind == SpaceProfile.adult ? SpaceProfile.adult : SpaceProfile.kids);
    _children.add(profile);
    return profile;
  }

  @override
  Future<SpaceProfile> updateProfile(SpaceProfile profile, {bool theme = true, bool details = true}) async {
    final i = _children.indexWhere((c) => c.id == profile.id);
    if (i < 0) throw StateError('Profile not found.');
    final old = _children[i];
    return _children[i] = old.copyWith(
        themeId: theme ? profile.themeId : null, details: details ? profile.details : null);
  }

  @override
  Future<void> deleteChild(String id) async {
    _children.removeWhere((c) => c.id == id);
    _entries.removeWhere((e) => e.childId == id);
    _links.removeWhere((l) => l.childId == id);
    _projects.removeWhere((p) => p.profileId == id);
  }

  @override
  Future<JournalEntry> saveEntry(JournalEntry entry) async {
    final saved = entry.id.isEmpty ? entry.copyWith(id: newId()) : entry;
    _entries.removeWhere((e) => e.id == saved.id);
    _entries.add(saved);
    return saved;
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _links.removeWhere((l) => l.fromId == id || l.toId == id);
  }

  @override
  Future<MemoryLink> addLink(MemoryLink link) async {
    final saved = MemoryLink(id: link.id.isEmpty ? newId() : link.id, childId: link.childId, fromId: link.fromId, toId: link.toId, label: link.label);
    _links.add(saved);
    return saved;
  }

  @override
  Future<void> deleteLink(String id) async => _links.removeWhere((l) => l.id == id);

  @override
  Future<AiInsight> analyze(String text, {required String kind}) => Future.error(StateError('AI is not connected in demo mode. Configure the backend and Gemini key.'));

  /// Offline stand-in for Gemini: simple template suggestions built from the
  /// selected entries, clearly flagged as demo samples.
  @override
  Future<List<StarIdea>> expand(String profileId, List<String> entryIds, {required String kind}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final picked = _entries.where((e) => e.childId == profileId && entryIds.contains(e.id)).toList();
    if (picked.isEmpty) throw StateError('Choose at least one entry.');
    final first = picked.first;
    final second = picked.length > 1 ? picked[1] : null;
    final tag = picked.expand((e) => e.tags).firstOrNull ?? (kind == SpaceProfile.adult ? 'this' : 'fun');
    final ids = picked.map((e) => e.id).toList();
    StarIdea make(String title, String detail, String type, List<String> sources) =>
        StarIdea(id: newId(), profileId: profileId, title: title, detail: detail, type: type, sourceIds: sources, demo: true);
    if (kind == SpaceProfile.adult) {
      return [
        make('Follow up on "${first.title}"', 'Note what happened next and anything you would do differently.', StarIdea.idea, [first.id]),
        make('Set a next step for ${tag.toLowerCase()}', 'Pick one small, concrete action for the coming week.', StarIdea.recommendation, ids),
        if (second != null) make('What links these entries?', 'Compare "${first.title}" and "${second.title}" and write down the common thread.', StarIdea.idea, [first.id, second.id]),
      ];
    }
    return [
      make('Another ${tag.toLowerCase()} adventure', 'You told a story about "${first.title}". What else could you try next time?', StarIdea.idea, [first.id]),
      make('Draw your favorite part', 'Make a picture of the best moment, then tell a story about your drawing.', StarIdea.recommendation, ids),
      if (second != null) make('Mix two stories together', 'What if "${first.title}" and "${second.title}" happened on the same day?', StarIdea.idea, [first.id, second.id]),
    ];
  }

  @override
  Future<List<WritingPrompt>> detailPrompts(String text, {required String kind, String? profileId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return demoAiPrompts(text, kids: kind != SpaceProfile.adult);
  }

  @override
  Future<String> transcribe(Uint8List wav) => Future.error(StateError('Speech model not configured. Connect an STT adapter in the backend.'));
}

/// Backend-controlled app API. The Dart client never holds Atlas or Gemini credentials.
/// DEV_API_TOKEN is for a private prototype only, not public production authentication.
class RemoteRepository implements MemoryRepository {
  RemoteRepository({required this.baseUrl, required this.devToken, http.Client? client}) : _client = client;
  final String baseUrl;
  final String devToken;

  /// Optional injected client (tests). Otherwise each call uses the zone's
  /// default client, so `http.runWithClient` keeps working too.
  final http.Client? _client;

  Future<T> _with<T>(Future<T> Function(http.Client c) run) async {
    final injected = _client;
    if (injected != null) return run(injected);
    final c = http.Client();
    try {
      return await run(c);
    } finally {
      c.close();
    }
  }
  @override
  bool get isDemo => false;

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
  Map<String, String> get _headers => {'Authorization': 'Bearer $devToken', 'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> _request(String method, String path, [Map<String, dynamic>? payload]) async {
    final uri = _uri(path);
    final response = await _with((c) => switch (method) {
          'GET' => c.get(uri, headers: _headers).timeout(const Duration(seconds: 15)),
          'POST' => c.post(uri, headers: _headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 20)),
          'PATCH' => c.patch(uri, headers: _headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 15)),
          'DELETE' => c.delete(uri, headers: _headers).timeout(const Duration(seconds: 15)),
          _ => throw ArgumentError('Unsupported method'),
        });
    final decoded = _decode(response.body);
    final route = path.split('?').first;
    if (response.statusCode == 404 && decoded['detail'] == 'Not Found') {
      throw ApiException(404, 'This feature needs the $route backend endpoint, which is not deployed yet.');
    }
    if (response.statusCode >= 400) throw ApiException(response.statusCode, _detail(decoded, response.statusCode));
    return decoded;
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return {};
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : {};
    } on FormatException {
      return {};
    }
  }

  /// FastAPI uses a string `detail`, or a list of problems for 422 validation errors.
  static String _detail(Map<String, dynamic> decoded, int status) {
    final detail = decoded['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) return 'Invalid request: ${detail.first is Map ? (detail.first as Map)['msg'] : detail.first}';
    return 'Server error $status';
  }

  @override
  Future<AppSnapshot> load() async => AppSnapshot.fromJson(await _request('GET', '/api/snapshot'));

  @override
  Future<SpaceProfile> addProfile(String name, String kind) async =>
      SpaceProfile.fromJson(await _request('POST', '/api/profiles', {'name': name, 'kind': kind}));

  @override
  Future<SpaceProfile> updateProfile(SpaceProfile profile, {bool theme = true, bool details = true}) async =>
      SpaceProfile.fromJson(await _request('PATCH', '/api/profiles/${Uri.encodeComponent(profile.id)}',
          {if (theme) 'themeId': profile.themeId, if (details) ...profile.details.toJson()}));

  @override
  Future<void> deleteChild(String id) async { await _request('DELETE', '/api/profiles/${Uri.encodeComponent(id)}'); }

  @override
  Future<JournalEntry> saveEntry(JournalEntry entry) async =>
      JournalEntry.fromJson(await _request('POST', '/api/entries', entry.toJson()));

  @override
  Future<void> deleteEntry(String id) async { await _request('DELETE', '/api/entries/${Uri.encodeComponent(id)}'); }

  @override
  Future<MemoryLink> addLink(MemoryLink link) async => MemoryLink.fromJson(await _request('POST', '/api/links', link.toJson()));

  @override
  Future<void> deleteLink(String id) async { await _request('DELETE', '/api/links/${Uri.encodeComponent(id)}'); }

  @override
  Future<AiInsight> analyze(String text, {required String kind}) async =>
      AiInsight.fromJson(await _request('POST', '/api/analyze', {'text': text, 'kind': kind}));

  /// Agreed contract, implemented in `backend/app.py` (owner-scoped, mocked
  /// Gemini tests in `backend/test_calendar.py`).
  ///
  /// `POST /api/expand`
  /// Request:  `{ "profileId": "...", "entryIds": ["..."], "kind": "kids" | "adult" }`
  ///           (1-6 IDs; the server loads the entries itself, scoped to the
  ///           authenticated owner and profile, rather than trusting client text)
  /// Response: `{ "ideas": [ { "title": "...", "detail": "...",
  ///             "type": "idea" | "recommendation", "sourceIds": ["..."] } ] }`
  ///           (2-4 ideas; sourceIds must be a subset of entryIds)
  /// Errors:   503 when GEMINI_API_KEY is unset, 502 when Gemini fails,
  ///           404 when an entry is not owned by this profile.
  @override
  Future<List<StarIdea>> expand(String profileId, List<String> entryIds, {required String kind}) async {
    final data = await _request('POST', '/api/expand', {'profileId': profileId, 'entryIds': entryIds, 'kind': kind});
    final allowed = entryIds.toSet();
    return ((data['ideas'] as List?) ?? [])
        .map((e) => StarIdea.fromJson(Map<String, dynamic>.from(e as Map), id: newId(), profileId: profileId, allowedSourceIds: allowed))
        .whereType<StarIdea>()
        .take(6)
        .toList();
  }

  /// Agreed contract, implemented in `backend/app.py` (mocked Gemini tests in
  /// `backend/test_calendar.py`).
  ///
  /// `POST /api/prompts`
  /// Request:  `{ "text": "<draft, 1-8000 chars>", "kind": "kids" | "adult", "profileId"?: "..." }`
  /// Response: `{ "prompts": [ { "label": "Who helped you?", "starter": "Someone who helped me was " } ] }`
  ///           (2-4 prompts; label ≤ 40 chars is the chip text; starter ≤ 80 chars
  ///           is an unfinished sentence the writer completes in their own words)
  /// Errors:   503 when GEMINI_API_KEY is unset, 502 when Gemini fails.
  /// The draft is not stored; it is only used to generate the prompts.
  @override
  Future<List<WritingPrompt>> detailPrompts(String text, {required String kind, String? profileId}) async {
    final data = await _request('POST', '/api/prompts',
        {'text': text, 'kind': kind, if (profileId != null) 'profileId': profileId});
    final seen = <String>{};
    return ((data['prompts'] as List?) ?? [])
        .whereType<Map<Object?, Object?>>()
        .map((e) => WritingPrompt.fromJson(Map<String, dynamic>.from(e)))
        .whereType<WritingPrompt>()
        .where((p) => seen.add(p.id))
        .take(4)
        .toList();
  }

  @override
  Future<String> transcribe(Uint8List wav) async {
    final request = http.MultipartRequest('POST', _uri('/api/transcribe'))
      ..headers['Authorization'] = 'Bearer $devToken'
      ..files.add(http.MultipartFile.fromBytes('file', wav, filename: 'daily-memory.wav', contentType: MediaType('audio', 'wav')));
    final http.Response response;
    try {
      response = await _with((c) async =>
          http.Response.fromStream(await c.send(request).timeout(const Duration(seconds: 95))));
    } on TimeoutException {
      throw const ApiException(504, 'Transcription timed out. Your notes are safe; try a shorter recording.');
    }
    final data = _decode(response.body);
    if (response.statusCode >= 400) throw ApiException(response.statusCode, transcribeErrorMessage(response.statusCode, _detail(data, response.statusCode)));
    final transcript = (data['transcript'] as String?)?.trim() ?? '';
    if (transcript.isEmpty) throw const ApiException(502, 'No speech was recognized. Try again, closer to the microphone.');
    return transcript;
  }

  @override
  Future<ProjectSpace> addProject(String profileId, String name) async =>
      ProjectSpace.fromJson(await _request('POST', '/api/projects', {'profileId': profileId, 'name': name.trim()}));

  @override
  Future<void> deleteProject(String id) async { await _request('DELETE', '/api/projects/${Uri.encodeComponent(id)}'); }

  @override
  Future<CalendarData> calendar(String profileId, CalendarView view, DateTime date, {String projectId = ''}) async {
    final query = Uri(queryParameters: {'profileId': profileId, 'view': view.wire, 'date': isoDay(date), 'projectId': projectId}).query;
    return CalendarData.fromJson(await _request('GET', '/api/calendar?$query'));
  }

  @override
  Future<CalendarSummary> calendarSummary(String profileId, CalendarView view, DateTime date, {String projectId = ''}) async =>
      CalendarSummary.fromJson(await _request('POST', '/api/calendar/summary',
          {'profileId': profileId, 'view': view.wire, 'date': isoDay(date), 'projectId': projectId}));
}

/// Friendly messages for `/api/transcribe` failures. Notes are never lost.
String transcribeErrorMessage(int status, String detail) => switch (status) {
      401 => 'The app is not authorized with the backend (check DEV_API_TOKEN).',
      413 => 'That recording is too long to upload. Try a shorter one.',
      415 || 422 => 'The recording could not be read. Please record again.',
      503 => 'Speech-to-text is not set up on the backend yet. You can type instead.',
      504 => 'Transcription timed out. Try a shorter recording.',
      502 => 'The speech service had a problem. Try again in a moment.',
      _ => detail,
    };
