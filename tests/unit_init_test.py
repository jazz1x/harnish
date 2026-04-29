"""Unit tests for harnish_py.init — legacy migration, idempotency."""
from pathlib import Path
from harnish_py.init import init_assets


def test_init_creates_files(tmp_path):
    base = tmp_path / ".harnish"
    init_assets(base_dir=str(base), quiet=True)
    assert (base / "harnish-assets.jsonl").exists()
    assert (base / "harnish-current-work.json").exists()


def test_init_idempotent(tmp_path):
    base = tmp_path / ".harnish"
    init_assets(base_dir=str(base), quiet=True)
    (base / "harnish-assets.jsonl").write_text('{"existing":true}\n')
    init_assets(base_dir=str(base), quiet=True)
    assert '{"existing":true}' in (base / "harnish-assets.jsonl").read_text()


def test_legacy_migration(tmp_path):
    base = tmp_path / ".harnish"
    base.mkdir()
    legacy = base / "harnish-rag.jsonl"
    legacy.write_text('{"old":"data"}\n')
    init_assets(base_dir=str(base), quiet=True)
    assert not legacy.exists()
    assert (base / "harnish-assets.jsonl").read_text() == '{"old":"data"}\n'
