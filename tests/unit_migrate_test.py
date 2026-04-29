"""Unit tests for harnish_py.migrate — backfill, no-op, backup gating."""
import json
from pathlib import Path
from harnish_py.io import jsonl_append, jsonl_read
from harnish_py.migrate import _cmd_migrate
import types


def _args(base_dir, target="0.0.2"):
    return types.SimpleNamespace(base_dir=str(base_dir), target=target)


def test_migrate_backfills_v001(tmp_path, capsys):
    base = tmp_path / ".harnish"
    base.mkdir()
    f = base / "harnish-assets.jsonl"
    jsonl_append(f, {"slug": "a", "schema_version": "0.0.1", "date": "2025-01-01"})
    rc = _cmd_migrate(_args(base))
    assert rc == 0
    captured = capsys.readouterr()
    out = json.loads(captured.out)
    assert out["status"] == "migrated"
    assert out["migrated"] == 1
    records = list(jsonl_read(f))
    assert records[0]["schema_version"] == "0.0.2"
    assert records[0]["access_count"] == 0


def test_migrate_noop_when_all_current(tmp_path, capsys):
    base = tmp_path / ".harnish"
    base.mkdir()
    f = base / "harnish-assets.jsonl"
    jsonl_append(f, {"slug": "b", "schema_version": "0.0.2"})
    rc = _cmd_migrate(_args(base))
    assert rc == 0
    captured = capsys.readouterr()
    out = json.loads(captured.out)
    assert out["status"] == "no-op"
    # No backup created
    bak_files = list(base.glob("harnish-assets.jsonl.bak.*"))
    assert len(bak_files) == 0


def test_migrate_creates_backup_only_when_migrating(tmp_path):
    base = tmp_path / ".harnish"
    base.mkdir()
    f = base / "harnish-assets.jsonl"
    jsonl_append(f, {"slug": "c", "schema_version": "0.0.1", "date": "2025-01-01"})
    _cmd_migrate(_args(base))
    bak_files = list(base.glob("harnish-assets.jsonl.bak.*"))
    assert len(bak_files) == 1


def test_migrate_noop_empty_file(tmp_path, capsys):
    base = tmp_path / ".harnish"
    base.mkdir()
    f = base / "harnish-assets.jsonl"
    f.write_text("")
    rc = _cmd_migrate(_args(base))
    assert rc == 0
    captured = capsys.readouterr()
    out = json.loads(captured.out)
    assert out["status"] == "no-op"
