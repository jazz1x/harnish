"""Unit tests for harnish_py.promote — dedup key, occurrences, empty file."""
import json
import os
import types
import tempfile
from pathlib import Path
from harnish_py.io import jsonl_read


def _make_pending(path, entries):
    with open(path, "w", encoding="utf-8") as f:
        for e in entries:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")


def test_dedup_by_tool_and_first_line(tmp_path):
    base = tmp_path / ".harnish"
    base.mkdir()
    (base / "harnish-assets.jsonl").touch()
    (base / "harnish-current-work.json").write_text("{}")

    pending = tmp_path / "pending.jsonl"
    _make_pending(pending, [
        {"tool": "Bash", "output": "Error: foo\ndetail", "session": "s", "date": "2026-01-01T00:00:00"},
        {"tool": "Bash", "output": "Error: foo\nother", "session": "s", "date": "2026-01-01T00:00:01"},
        {"tool": "Bash", "output": "Error: bar\ndetail", "session": "s", "date": "2026-01-01T00:00:02"},
    ])

    from harnish_py.promote import _cmd_promote
    args = types.SimpleNamespace(
        session="test-dedup", base_dir=str(base), dry_run=True,
    )

    # Monkey-patch the pending file path
    import harnish_py.promote as pm
    orig_path = f"/tmp/harnish-pending-test-dedup.jsonl"
    import shutil
    shutil.copy2(pending, orig_path)

    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_promote(args)
    out = json.loads(buf.getvalue())

    assert out["status"] == "dry_run"
    assert out["promoted"] == 2  # foo and bar
    assert out["deduplicated"] == 1  # one foo duplicate

    # cleanup
    Path(orig_path).unlink(missing_ok=True)


def test_empty_pending_returns_empty(tmp_path):
    from harnish_py.promote import _cmd_promote
    import io, contextlib

    args = types.SimpleNamespace(
        session="nonexistent-session-xyz", base_dir=str(tmp_path), dry_run=False,
    )
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_promote(args)
    out = json.loads(buf.getvalue())
    assert out["status"] == "no_pending"
