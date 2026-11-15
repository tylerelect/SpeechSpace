import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:speechspace/models/models.dart';
import 'package:speechspace/services/app_controller.dart';
import 'package:speechspace/services/repository.dart';

/// Records PATCH bodies and can be told to fail them, to check what each save
/// sends and what happens when the follow-up save after creating a profile fails.
class _Backend {
  final profiles = <Map<String, dynamic>>[
    {'id': 'k1', 'name': 'Kid', 'kind': 'kids', 'themeId': 'space', 'school': 'Maple School'},
  ];
  final patchBodies = <Map<String, dynamic>>[];
  int posts = 0;
  bool failPatch = false;

  MockClient get client => MockClient((req) async {
        http.Response json(Object body) => http.Response(jsonEncode(body), 200);
        final path = req.url.path;
        if (req.method == 'GET' && path == '/api/snapshot') {
          return json({'children': profiles, 'projects': <Object>[], 'entries': <Object>[], 'links': <Object>[]});
        }
        if (req.method == 'POST' && path == '/api/profiles') {
          posts++;
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final p = {'id': 'p$posts', 'name': body['name'], 'kind': body['kind'], 'themeId': 'space'};
          profiles.add(p);
          return json(p);
        }
        if (req.method == 'PATCH') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          patchBodies.add(body);
          if (failPatch) return http.Response(jsonEncode({'detail': 'Nope.'}), 422);
          final p = profiles.firstWhere((p) => p['id'] == path.split('/').last)..addAll(body);
          return json(p);
        }
        return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
      });
}

void main() {
  Future<(AppController, _Backend)> start() async {
    final b = _Backend();
    final c = AppController(RemoteRepository(baseUrl: 'http://test', devToken: 't', client: b.client),
        persistSelection: false);
    await c.initialize();
    return (c, b);
  }

  test('a theme change sends only the theme; a details save sends only details', () async {
    final (c, b) = await start();
    await c.setTheme('ocean');
    expect(b.patchBodies.last.keys, ['themeId']);
    await c.setDetails(const ProfileDetails(age: 8, school: 'Oak School'));
    expect(b.patchBodies.last.containsKey('themeId'), isFalse);
    expect(b.patchBodies.last['school'], 'Oak School');
    expect(c.profile?.themeId, 'ocean');
  });

  test('if saving details after creating a profile fails, the profile is kept and not duplicated', () async {
    final (c, b) = await start();
    b.failPatch = true;
    await expectLater(c.addProfile('Riley', SpaceProfile.kids, details: const ProfileDetails(age: 6)),
        throwsA(isA<ProfileSetupIncomplete>()));
    expect(b.posts, 1);
    expect(c.profiles.where((p) => p.name == 'Riley'), hasLength(1));
    expect(c.profile?.name, 'Riley'); // selected, so the setup page can go on with it
  });

  test('creating a profile with only details does not resend the default theme', () async {
    final (c, b) = await start();
    await c.addProfile('Riley', SpaceProfile.kids, themeId: 'space', details: const ProfileDetails(school: 'Oak'));
    expect(b.patchBodies.single.containsKey('themeId'), isFalse);
    expect(c.profile?.details.school, 'Oak');
  });
}
