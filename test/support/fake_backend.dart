import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory stand-in for the FastAPI backend, for remote-mode tests.
///
/// Mirrors the real contract in `backend/app.py`: the snapshot uses the legacy
/// `children` key, entry calendar days are the first 10 characters of the
/// stored ISO date, weeks start on Monday, entries are newest first and capped,
/// and summaries are only produced by an explicit POST. Synthetic data only.
class FakeBackend {
  FakeBackend({List<Map<String, dynamic>>? profiles})
      : profiles = profiles ??
            [
              {'id': 'k1', 'name': 'Kid', 'kind': 'kids', 'themeId': 'space'},
              {'id': 'a1', 'name': 'Grown-up', 'kind': 'adult', 'themeId': 'indigo'},
            ];

  final List<Map<String, dynamic>> profiles;
  final projects = <Map<String, dynamic>>[];
  final entries = <Map<String, dynamic>>[];
  final links = <Map<String, dynamic>>[];

  /// Every request as `METHOD /path?query`.
  final requests = <String>[];
  final patches = <String>[];

  int calendarCap = 200;

  /// When set, `/api/calendar/summary` fails with this status.
  int? summaryStatus;

  /// When set, `/api/calendar/summary` returns this body (merged over the counts).
  Map<String, dynamic>? summaryBody;

  /// When set, `/api/calendar` fails with this status.
  int? calendarStatus;

  /// When set, `/api/expand` fails with this status.
  int? expandStatus;

  /// Throw a network error (as if offline) for paths starting with this.
  String? offlinePrefix;

  /// Optional gate awaited before answering a request (to simulate slow responses).
  Future<void> Function(http.Request request)? beforeRespond;

  int _id = 0;
  String _newId(String prefix) => '$prefix-${++_id}';

  /// Adds a stored entry on the calendar day [day] (YYYY-MM-DD).
  Map<String, dynamic> addEntry(String profileId, String day,
      {String? id, String project = '', bool milestone = false, String? title, String time = 'T00:00:00.000'}) {
    final entry = {
      'id': id ?? _newId('e'),
      'childId': profileId,
      'projectId': project,
      'date': '$day$time',
      'title': title ?? 'Entry $day',
      'body': 'Synthetic note.',
      'favorite': '',
      'highlight': '',
      'isMilestone': milestone,
      'tags': <String>[],
    };
    entries.add(entry);
    return entry;
  }

  int count(String prefix) => requests.where((r) => r.startsWith(prefix)).length;

  static http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
  static http.Response _error(int status, String detail) => _json({'detail': detail}, status);

  MockClient get client => MockClient((req) async {
        final path = req.url.path;
        requests.add('${req.method} $path${req.url.hasQuery ? '?${req.url.query}' : ''}');
        if (beforeRespond != null) await beforeRespond!(req);
        if (offlinePrefix != null && path.startsWith(offlinePrefix!)) {
          throw http.ClientException('Connection refused', req.url);
        }
        if (req.headers['Authorization'] != 'Bearer t') return _error(401, 'Unauthorized demo token.');
        final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;

        if (req.method == 'GET' && path == '/api/snapshot') {
          return _json({'children': profiles, 'projects': projects, 'entries': entries, 'links': links});
        }
        if (req.method == 'POST' && path == '/api/profiles') {
          final kind = body['kind'] == 'adult' ? 'adult' : 'kids';
          final p = {'id': _newId('p'), 'name': body['name'], 'kind': kind, 'themeId': kind == 'kids' ? 'space' : 'indigo'};
          profiles.add(p);
          return _json(p);
        }
        if (req.method == 'PATCH' && path.startsWith('/api/profiles/')) {
          final id = path.split('/').last;
          final p = profiles.where((p) => p['id'] == id).firstOrNull;
          if (p == null) return _error(404, 'Profile not found.');
          final allowed = p['kind'] == 'adult' ? ['indigo', 'teal', 'slate'] : ['space', 'ocean', 'sunshine'];
          if (body.containsKey('themeId')) {
            if (!allowed.contains(body['themeId'])) return _error(422, 'Invalid theme for profile kind.');
            if (body['themeId'] != p['themeId']) patches.add('$id:${body['themeId']}');
            p['themeId'] = body['themeId'];
          }
          for (final key in const ['age', 'school', 'favoriteColor', 'interests', 'occupation', 'goals']) {
            if (body.containsKey(key)) p[key] = body[key];
          }
          return _json(p);
        }
        if (req.method == 'DELETE' && path.startsWith('/api/profiles/')) {
          final id = path.split('/').last;
          profiles.removeWhere((p) => p['id'] == id);
          projects.removeWhere((p) => p['profileId'] == id);
          entries.removeWhere((e) => e['childId'] == id);
          links.removeWhere((l) => l['childId'] == id);
          return _json({'deleted': true});
        }
        if (req.method == 'POST' && path == '/api/projects') {
          if (!profiles.any((p) => p['id'] == body['profileId'])) return _error(404, 'Profile not found.');
          final p = {'id': _newId('proj'), 'profileId': body['profileId'], 'name': body['name']};
          projects.add(p);
          return _json(p);
        }
        if (req.method == 'DELETE' && path.startsWith('/api/projects/')) {
          final id = path.split('/').last;
          projects.removeWhere((p) => p['id'] == id);
          for (final e in entries) { if (e['projectId'] == id) e['projectId'] = ''; }
          return _json({'deleted': true});
        }
        if (req.method == 'POST' && path == '/api/entries') {
          final id = (body['id'] as String?)?.isNotEmpty == true ? body['id'] as String : _newId('e');
          final saved = {...body, 'id': id};
          entries.removeWhere((e) => e['id'] == id);
          entries.add(saved);
          return _json(saved);
        }
        if (req.method == 'DELETE' && path.startsWith('/api/entries/')) {
          final id = path.split('/').last;
          entries.removeWhere((e) => e['id'] == id);
          links.removeWhere((l) => l['fromId'] == id || l['toId'] == id);
          return _json({'deleted': true});
        }
        if (req.method == 'POST' && path == '/api/links') {
          if (body['fromId'] == body['toId']) return _error(422, 'Choose different memories.');
          final dup = links.any((l) => l['childId'] == body['childId'] &&
              ((l['fromId'] == body['fromId'] && l['toId'] == body['toId']) ||
                  (l['fromId'] == body['toId'] && l['toId'] == body['fromId'])));
          if (dup) return _error(409, 'These memories are already linked.');
          final saved = {...body, 'id': _newId('l')};
          links.add(saved);
          return _json(saved);
        }
        if (req.method == 'DELETE' && path.startsWith('/api/links/')) {
          final id = path.split('/').last;
          links.removeWhere((l) => l['id'] == id);
          return _json({'deleted': true});
        }
        if (req.method == 'GET' && path == '/api/calendar') {
          if (calendarStatus != null) return _error(calendarStatus!, 'Calendar unavailable.');
          final q = req.url.queryParameters;
          final scope = _scope(q['profileId'] ?? '', q['view'] ?? '', q['date'] ?? '', q['projectId'] ?? '');
          if (scope is http.Response) return scope;
          final s = scope as _Scope;
          final perDay = <String, Map<String, dynamic>>{};
          for (final e in s.records) {
            final day = (e['date'] as String).substring(0, 10);
            final b = perDay.putIfAbsent(day, () => {'date': day, 'entryCount': 0, 'milestoneCount': 0});
            b['entryCount'] = (b['entryCount'] as int) + 1;
            if (e['isMilestone'] == true) b['milestoneCount'] = (b['milestoneCount'] as int) + 1;
          }
          final returned = s.records.take(calendarCap).toList();
          return _json({
            ...s.base,
            'days': [for (final k in (perDay.keys.toList()..sort())) perDay[k]],
            'entries': returned,
            'returnedCount': returned.length,
            'truncated': s.records.length > returned.length,
          });
        }
        if (req.method == 'POST' && path == '/api/calendar/summary') {
          final scope = _scope(body['profileId'] as String? ?? '', body['view'] as String? ?? '', body['date'] as String? ?? '', body['projectId'] as String? ?? '');
          if (scope is http.Response) return scope;
          final s = scope as _Scope;
          if (s.records.isEmpty) {
            return _json({...s.base, 'generated': false, 'partial': false, 'analyzedEntries': 0, 'sourceEntryIds': <String>[],
                'summary': 'No entries recorded for this ${body['view']}.', 'highlights': <String>[], 'themes': <String>[], 'milestones': <Object>[]});
          }
          if (summaryStatus == 503) return _error(503, 'Gemini Flash not configured. Set GEMINI_API_KEY.');
          if (summaryStatus != null) return _error(summaryStatus!, 'Gemini summary unavailable. Try again later.');
          final sample = s.records.take(40).toList();
          return _json({
            ...s.base,
            'generated': true,
            'partial': sample.length < s.records.length,
            'analyzedEntries': sample.length,
            'sourceEntryIds': [for (final e in sample) e['id']],
            'summary': 'Recorded ${s.records.length} entries.',
            'highlights': ['Recorded activity'],
            'themes': ['Activities'],
            'milestones': [for (final e in sample) if (e['isMilestone'] == true) e['title']],
            ...?summaryBody,
          });
        }
        if (req.method == 'POST' && path == '/api/expand') {
          if (expandStatus == 503) return _error(503, 'Gemini Flash not configured. Set GEMINI_API_KEY.');
          if (expandStatus != null) return _error(expandStatus!, 'Gemini ideas unavailable. Try again later.');
          final ids = (body['entryIds'] as List).cast<String>();
          return _json({'ideas': [
            {'title': 'Try it again', 'detail': 'Based on your note.', 'type': 'idea', 'sourceIds': [ids.first]},
            {'title': 'A small next step', 'detail': 'Something safe to try.', 'type': 'recommendation', 'sourceIds': ids},
          ]});
        }
        if (path == '/api/transcribe') return _error(503, 'Speech adapter not configured.');
        return _error(404, 'Not Found');
      });

  /// Shared validation + period computation, like `calendar_scope` in the backend.
  Object _scope(String profileId, String view, String day, String projectId) {
    final profile = profiles.where((p) => p['id'] == profileId).firstOrNull;
    if (profile == null) return _error(404, 'Profile not found.');
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
    if (m == null) return _error(422, 'Date must be YYYY-MM-DD.');
    final a = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    late DateTime start, end;
    switch (view) {
      case 'day': start = a; end = a.add(const Duration(days: 1));
      case 'week': start = a.subtract(Duration(days: a.weekday - 1)); end = start.add(const Duration(days: 7));
      case 'month': start = DateTime.utc(a.year, a.month); end = DateTime.utc(a.year, a.month + 1);
      case 'year': start = DateTime.utc(a.year); end = DateTime.utc(a.year + 1);
      default: return _error(422, 'View must be day, week, month, or year.');
    }
    if (projectId.isNotEmpty && !projects.any((p) => p['id'] == projectId && p['profileId'] == profileId)) {
      return _error(422, 'Project must belong to the selected profile.');
    }
    String iso(DateTime d) => d.toIso8601String().substring(0, 10);
    final s = iso(start), e = iso(end);
    final records = entries.where((x) {
      final d = (x['date'] as String).substring(0, 10);
      return x['childId'] == profileId && (projectId.isEmpty || x['projectId'] == projectId) &&
          d.compareTo(s) >= 0 && d.compareTo(e) < 0;
    }).toList()
      ..sort((x, y) {
        final c = (y['date'] as String).compareTo(x['date'] as String);
        return c != 0 ? c : (y['id'] as String).compareTo(x['id'] as String);
      });
    return _Scope(records, {
      'profileId': profileId,
      'view': view,
      'projectId': projectId,
      'period': {'start': s, 'endExclusive': e, 'label': '$view of $s'},
      'entryCount': records.length,
      'activeDays': records.map((x) => (x['date'] as String).substring(0, 10)).toSet().length,
      'milestoneCount': records.where((x) => x['isMilestone'] == true).length,
    });
  }
}

class _Scope {
  _Scope(this.records, this.base);
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic> base;
}

/// A gate that holds matching requests until [release] is called.
class RequestGate {
  final _completers = <Completer<void>>[];
  Future<void> wait() {
    final c = Completer<void>();
    _completers.add(c);
    return c.future;
  }

  void release() {
    for (final c in _completers) { if (!c.isCompleted) c.complete(); }
    _completers.clear();
  }
}
