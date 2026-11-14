"""Run after: pip install -r requirements.txt && pip install pytest mongomock"""
from fastapi.testclient import TestClient
import mongomock
import app as backend


def test_memory_lifecycle():
    db = mongomock.MongoClient()['unit_test']
    backend.app.dependency_overrides[backend.parent_actor] = lambda: 'test-parent'
    old_db = backend.db
    backend.db = lambda: db
    try:
        client = TestClient(backend.app)
        child = client.post('/api/children', json={'name': 'Demo kid'}).json()
        assert child['id']
        entry1 = client.post('/api/entries', json={
            'childId': child['id'], 'date': '2026-11-14T00:00:00',
            'title': 'First', 'body': 'A paper airplane was fun today.',
        }).json()
        entry2 = client.post('/api/entries', json={
            'childId': child['id'], 'date': '2026-11-15T00:00:00',
            'title': 'Second', 'body': 'I made another paper airplane.',
        }).json()
        link = client.post('/api/links', json={
            'childId': child['id'], 'fromId': entry1['id'],
            'toId': entry2['id'], 'label': 'paper airplanes',
        }).json()
        assert link['id']
        snapshot = client.get('/api/snapshot').json()
        assert len(snapshot['children']) == 1
        assert len(snapshot['entries']) == 2
        assert len(snapshot['links']) == 1
        assert client.delete(f"/api/entries/{entry1['id']}").status_code == 200
        assert client.get('/api/snapshot').json()['links'] == []
    finally:
        backend.app.dependency_overrides.clear()
        backend.db = old_db
