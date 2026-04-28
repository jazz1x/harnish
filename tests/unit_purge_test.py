"""Unit tests for harnish_py.purge — TTL boundary, dry-run, pattern immunity."""
import json
import types
import io
import contextlib
from harnish_py.io import jsonl_append, jsonl_read
from harnish_py.purge import _cmd_purge


def test_dry_run_no_change(tmp_path):
    base = tmp_path / ".harnish"
    base.mkdir()
    af = base / "harnish-assets.jsonl"
    jsonl_append(af, {
        "slug": "old", "type": "decision", "title": "old",
        "tags": ["x"], "date": "2020-01-01", "scope": "generic",
        "body": "b", "context": "c", "session": "s",
        "last_accessed_at": "2020-01-01", "access_count": 0,
    })
    before = af.read_text()

    args = types.SimpleNamespace(execute=False, base_dir=str(base))
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_purge(args)
    out = json.loads(buf.getvalue())
    assert out["status"] == "dry_run"
    assert af.read_text() == before


def test_pattern_never_purged(tmp_path):
    base = tmp_path / ".harnish"
    base.mkdir()
    af = base / "harnish-assets.jsonl"
    jsonl_append(af, {
        "slug": "old-pattern", "type": "pattern", "title": "p",
        "tags": ["x"], "date": "2020-01-01", "scope": "generic",
        "body": "b", "context": "c", "session": "s",
    })

    args = types.SimpleNamespace(execute=True, base_dir=str(base))
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_purge(args)
    out = json.loads(buf.getvalue())
    assert out.get("purged", 0) == 0 or out["status"] == "no_candidates"


def test_execute_archives(tmp_path):
    base = tmp_path / ".harnish"
    base.mkdir()
    af = base / "harnish-assets.jsonl"
    jsonl_append(af, {
        "slug": "expired", "type": "failure", "title": "old fail",
        "tags": ["x"], "date": "2020-01-01", "scope": "generic",
        "body": "b", "context": "c", "session": "s",
        "access_count": 0,
    })

    args = types.SimpleNamespace(execute=True, base_dir=str(base))
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_purge(args)
    out = json.loads(buf.getvalue())
    assert out["status"] == "purged"
    assert out["purged"] == 1

    archive = base / "harnish-assets-archive.jsonl"
    assert archive.exists()
