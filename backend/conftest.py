"""Shared test setup: neutralize integration settings loaded from any local .env."""
from __future__ import annotations

import pytest

try:
    from . import app as backend
except ImportError:
    import app as backend


@pytest.fixture(autouse=True)
def isolated_integrations(monkeypatch):
    monkeypatch.setattr(backend, 'GEMINI_KEY', '')
    monkeypatch.setattr(backend, 'STT_URL', '')
    monkeypatch.setattr(backend, 'STT_TOKEN', '')
    monkeypatch.setattr(backend, 'STT_PROVIDER', '')
    monkeypatch.setattr(backend, 'ELEVENLABS_API_KEY', '')
    monkeypatch.setattr(backend, 'ELEVENLABS_STT_MODEL', '')

    def no_network(*_args, **_kwargs):
        raise AssertionError('Tests must mock generate_structured; no live Gemini calls.')

    monkeypatch.setattr(backend, 'generate_structured', no_network)
