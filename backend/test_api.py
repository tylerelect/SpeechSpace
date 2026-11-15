"""API contract tests: use synthetic data and mocked integrations, never live keys."""
from __future__ import annotations

import struct

import httpx
import mongomock
import pytest
from fastapi.testclient import TestClient

try:
    from . import app as backend
except ImportError:
    import app as backend


@pytest.fixture
def ctx(monkeypatch):
    database = mongomock.MongoClient()['speechspace_test']
    backend.ensure_indexes(database)
    monkeypatch.setattr(backend, 'db', lambda: database)
    backend.app.dependency_overrides[backend.parent_actor] = lambda: 'parent-one'
    client = TestClient(backend.app)
    yield client, database
    client.close()
    backend.app.dependency_overrides.clear()


def change_parent(parent):
    backend.app.dependency_overrides[backend.parent_actor] = lambda: parent


def make_profile(client, kind='kids', name='Sample'):
    response = client.post('/api/profiles', json={'kind': kind, 'name': name})
    assert response.status_code == 200, response.text
    return response.json()


def make_entry(client, profile_id, title='Drawing', project_id=''):
    response = client.post('/api/entries', json={
        'childId': profile_id, 'projectId': project_id,
        'date': '2026-11-14T13:00:00Z', 'title': title,
        'body': 'I drew a colorful kite today.',
    })
    assert response.status_code == 200, response.text
    return response.json()


def test_legacy_profiles_and_persistent_themes(ctx):
    client, database = ctx
    database.children.insert_one({'ownerId': 'parent-one', 'id': 'old-1', 'name': 'Legacy'})
    kids = make_profile(client, 'kids', '  Sky  ')
    adult = make_profile(client, 'adult', 'Parent')
    assert kids == {'id': kids['id'], 'name': 'Sky', 'kind': 'kids', 'themeId': 'space'}
    assert adult['themeId'] == 'indigo'
    assert client.patch(f"/api/profiles/{kids['id']}", json={'themeId': 'ocean'}).json()['themeId'] == 'ocean'
    assert client.patch(f"/api/profiles/{adult['id']}", json={'themeId': 'slate'}).json()['themeId'] == 'slate'
    assert client.patch(f"/api/profiles/{kids['id']}", json={'themeId': 'slate'}).status_code == 422
    assert client.patch(f"/api/profiles/{adult['id']}", json={'themeId': 'space'}).status_code == 422
    profiles = {x['id']: x for x in client.get('/api/snapshot').json()['children']}
    assert profiles['old-1']['kind'] == 'kids' and profiles['old-1']['themeId'] == 'space'
    assert profiles[kids['id']]['themeId'] == 'ocean'
    assert profiles[adult['id']]['themeId'] == 'slate'
    assert database.children.find_one({'id': kids['id']})['themeId'] == 'ocean'


def test_profile_input_validations_and_old_alias(ctx):
    client, _ = ctx
    assert client.post('/api/profiles', json={'name': 'A', 'kind': 'other'}).status_code == 422
    assert client.post('/api/profiles', json={'name': '  ', 'kind': 'kids'}).status_code == 422
    old = client.post('/api/children', json={'name': 'Legacy kid'}).json()
    assert old['kind'] == 'kids'
    assert client.delete(f"/api/children/{old['id']}").json() == {'deleted': True}


def test_projects_entries_and_deletion_preserve_memories(ctx):
    client, _ = ctx
    kids = make_profile(client, 'kids', 'Kit')
    adult = make_profile(client, 'adult', 'Jamie')
    project_response = client.post('/api/projects', json={'profileId': kids['id'], 'name': '  Astronomy  '})
    assert project_response.status_code == 200
    project = project_response.json()
    assert project['name'] == 'Astronomy'
    assert 'ownerId' not in project
    entry = make_entry(client, kids['id'], project_id=project['id'])
    assert entry['projectId'] == project['id']
    assert client.post('/api/entries', json={
        'childId': adult['id'], 'date': '2026-11-14', 'title': 'Wrong project',
        'body': 'Example', 'projectId': project['id'],
    }).status_code == 422
    assert client.post('/api/entries', json={
        'childId': kids['id'], 'date': '2026-11-14', 'title': 'Missing project',
        'body': 'Example', 'projectId': 'not-a-project',
    }).status_code == 404
    assert client.delete(f"/api/projects/{project['id']}").json() == {'deleted': True}
    snapshot = client.get('/api/snapshot').json()
    assert snapshot['projects'] == []
    assert snapshot['entries'][0]['id'] == entry['id']
    assert snapshot['entries'][0]['projectId'] == ''


def test_links_are_profile_scoped_and_unique(ctx):
    client, _ = ctx
    a = make_profile(client, name='Alpha')
    b = make_profile(client, name='Beta')
    one = make_entry(client, a['id'], 'First')
    two = make_entry(client, a['id'], 'Second')
    other = make_entry(client, b['id'], 'Other')
    payload = {'childId': a['id'], 'fromId': one['id'], 'toId': two['id']}
    link = client.post('/api/links', json=payload)
    assert link.status_code == 200
    assert client.post('/api/links', json={**payload, 'fromId': two['id'], 'toId': one['id']}).status_code == 409
    assert client.post('/api/links', json={**payload, 'toId': other['id']}).status_code == 404
    assert client.post('/api/links', json={**payload, 'toId': one['id']}).status_code == 422
    client.delete(f"/api/entries/{one['id']}")
    assert client.get('/api/snapshot').json()['links'] == []


def test_profile_cascade_and_owner_isolation(ctx):
    client, database = ctx
    a = make_profile(client, 'kids', 'Test A')
    b = make_profile(client, 'adult', 'Test B')
    project = client.post('/api/projects', json={'profileId': a['id'], 'name': 'A proj'}).json()
    first = make_entry(client, a['id'], 'A entry', project['id'])
    second = make_entry(client, a['id'], 'Another')
    b_entry = make_entry(client, b['id'], 'B entry')
    link = client.post('/api/links', json={'childId': a['id'], 'fromId': first['id'], 'toId': second['id']}).json()

    change_parent('parent-two')
    assert client.get('/api/snapshot').json() == {'children': [], 'projects': [], 'entries': [], 'links': []}
    assert client.patch(f"/api/profiles/{a['id']}", json={'themeId': 'ocean'}).status_code == 404
    assert client.delete(f"/api/profiles/{a['id']}").status_code == 404
    assert client.delete(f"/api/projects/{project['id']}").status_code == 404
    assert client.delete(f"/api/entries/{first['id']}").status_code == 404
    assert client.delete(f"/api/links/{link['id']}").status_code == 404
    assert client.post('/api/projects', json={'profileId': a['id'], 'name': 'Nope'}).status_code == 404

    change_parent('parent-one')
    assert client.delete(f"/api/profiles/{a['id']}").json() == {'deleted': True}
    remaining = client.get('/api/snapshot').json()
    assert [c['id'] for c in remaining['children']] == [b['id']]
    assert [e['id'] for e in remaining['entries']] == [b_entry['id']]
    assert remaining['links'] == [] and remaining['projects'] == []
    assert not database.children.find_one({'id': a['id']})


def test_invalid_entry_input(ctx):
    client, _ = ctx
    profile = make_profile(client)
    base = {'childId': profile['id'], 'title': 'Test', 'body': 'Test', 'date': '2026-11-14'}
    assert client.post('/api/entries', json={**base, 'date': 'not-a-date'}).status_code == 422
    assert client.post('/api/entries', json={**base, 'tags': ['x' * 61]}).status_code == 422
    assert client.post('/api/entries', json={**base, 'title': '  '}).status_code == 422
    assert client.post('/api/entries', json={**base, 'id': 'nonexistent'}).status_code == 404


def test_requires_demo_authentication(ctx, monkeypatch):
    client, _ = ctx
    backend.app.dependency_overrides.clear()
    monkeypatch.setattr(backend, 'DEV_TOKEN', 'synthetic-token-only')
    assert client.get('/health').status_code == 200
    assert client.get('/api/snapshot').status_code == 401
    assert client.get('/api/snapshot', headers={'Authorization': 'Bearer wrong'}).status_code == 401
    assert client.get('/api/snapshot', headers={'Authorization': 'Bearer synthetic-token-only'}).status_code == 200


def test_gemini_modes_and_failure_paths(ctx, monkeypatch):
    client, _ = ctx
    monkeypatch.setattr(backend, 'GEMINI_KEY', '')
    assert client.post('/api/analyze', json={'text': 'Today I drew a kite.'}).status_code == 503
    monkeypatch.setattr(backend, 'GEMINI_KEY', 'not-real')
    calls = []

    def mock_response(text, kind):
        calls.append((text, kind))
        return {'highlight': 'Drew a kite.', 'favorite': '', 'tags': ['art']}

    monkeypatch.setattr(backend, 'generate_gemini_insight', mock_response)
    response = client.post('/api/analyze', json={'text': 'Today I drew a kite.', 'kind': 'adult'})
    assert response.status_code == 200
    assert response.json()['highlight'] == 'Drew a kite.'
    assert calls[-1] == ('Today I drew a kite.', 'adult')
    assert client.post('/api/analyze', json={'text': 'A child remembers.'}).status_code == 200
    assert calls[-1][1] == 'kids'
    assert client.post('/api/analyze', json={'text': 'x', 'kind': 'invalid'}).status_code == 422

    monkeypatch.setattr(backend, 'generate_gemini_insight', lambda *_: {'highlight': 'x', 'favorite': '', 'tags': ['a'] * 4})
    assert client.post('/api/analyze', json={'text': 'x'}).status_code == 502

    def broken(*_):
        raise RuntimeError('secret-provider-detail')

    monkeypatch.setattr(backend, 'generate_gemini_insight', broken)
    failed = client.post('/api/analyze', json={'text': 'sensitive synthetic sample'})
    assert failed.status_code == 502
    assert 'secret-provider-detail' not in failed.text
    assert 'sensitive synthetic sample' not in failed.text


def wav_bytes():
    # RIFF/WAVE header + mock PCM data; sufficient for transport-level validation.
    return b'RIFF' + struct.pack('<I', 36) + b'WAVE' + bytes(36)


def test_transcription_and_errors(ctx, monkeypatch):
    client, _ = ctx
    monkeypatch.setattr(backend, 'STT_URL', '')
    assert client.post('/api/transcribe', files={'file': ('note.wav', wav_bytes(), 'audio/wav')}).status_code == 503
    monkeypatch.setattr(backend, 'STT_URL', 'https://not-real.example/transcribe')
    assert client.post('/api/transcribe', files={'file': ('note.txt', b'hello', 'text/plain')}).status_code == 415
    assert client.post('/api/transcribe', files={'file': ('note.wav', b'not-wave' * 6, 'audio/wav')}).status_code == 422
    assert client.post('/api/transcribe', files={'file': ('note.wav', wav_bytes() + b'0' * 3_000_000, 'audio/wav')}).status_code == 413

    async def fake_stt(audio):
        assert audio.startswith(b'RIFF')
        return 'A pretend memory.'

    monkeypatch.setattr(backend, 'call_stt_service', fake_stt)
    result = client.post('/api/transcribe', files={'file': ('note.wav', wav_bytes(), 'audio/wav')})
    assert result.status_code == 200
    assert result.json() == {'transcript': 'A pretend memory.'}

    async def timeout(audio):
        raise httpx.ReadTimeout('mock timeout')

    monkeypatch.setattr(backend, 'call_stt_service', timeout)
    assert client.post('/api/transcribe', files={'file': ('note.wav', wav_bytes(), 'audio/wav')}).status_code == 504

    async def malformed(audio):
        raise ValueError('bad upstream result')

    monkeypatch.setattr(backend, 'call_stt_service', malformed)
    assert client.post('/api/transcribe', files={'file': ('note.wav', wav_bytes(), 'audio/wav')}).status_code == 502


def test_upstream_stt_adapter_responses(monkeypatch):
    import asyncio
    original_client = httpx.AsyncClient
    monkeypatch.setattr(backend, 'STT_URL', 'https://example.invalid/stt')
    monkeypatch.setattr(backend, 'STT_TOKEN', 'synthetic-adapter-token')

    def run_mock(handler):
        transport = httpx.MockTransport(handler)
        monkeypatch.setattr(
            backend.httpx, 'AsyncClient',
            lambda *args, **kwargs: original_client(transport=transport, *args, **kwargs),
        )
        return asyncio.run(backend.call_stt_service(wav_bytes()))

    def success(request):
        assert request.headers['authorization'] == 'Bearer synthetic-adapter-token'
        return httpx.Response(200, json={'transcript': 'I learned about planets.'})

    assert run_mock(success) == 'I learned about planets.'
    assert run_mock(lambda req: httpx.Response(200, json={'text': 'Backup text field.'})) == 'Backup text field.'
    with pytest.raises(ValueError):
        run_mock(lambda req: httpx.Response(200, json={'transcript': '   '}))
    with pytest.raises(ValueError):
        run_mock(lambda req: httpx.Response(200, text='not-json'))
    with pytest.raises(httpx.HTTPStatusError):
        run_mock(lambda req: httpx.Response(503, json={'detail': 'private upstream failure'}))
