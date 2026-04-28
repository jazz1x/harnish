"""Unit tests for harnish_py.compress — threshold, dry-run, grouping."""
import json
import types
import io
import contextlib
from harnish_py.io import jsonl_append, jsonl_read
from harnish_py.compress import _cmd_compress


def _setup(tmp_path, n=6):
    base = tmp_path / ".harnish"
    base.mkdir()
    af = base / "harnish-assets.jsonl"
    for i in range(n):
        jsonl_append(af, {
            "slug": f"p{i}", "type": "pattern", "title": f"t{i}",
            "tags": ["test-tag"], "date": "2026-01-01",
            "scope": "generic", "body": "b", "context": "c", "session": "s",
        })
    return str(base)


def test_compress_marks_records(tmp_path):
    base = _setup(tmp_path, 6)
    args = types.SimpleNamespace(
        tag="test-tag", all_tags=False, threshold=5,
        dry_run=False, base_dir=base,
    )
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_compress(args)
    out = json.loads(buf.getvalue())
    assert out["status"] == "compressed"
    assert out["compressed"] == 1

    records = list(jsonl_read(f"{base}/harnish-assets.jsonl"))
    compressed = [r for r in records if r.get("compressed") is True]
    assert len(compressed) >= 6  # 6 originals marked + maybe summary


def test_dry_run_no_change(tmp_path):
    base = _setup(tmp_path, 6)
    af = f"{base}/harnish-assets.jsonl"
    before = open(af).read()

    args = types.SimpleNamespace(
        tag="test-tag", all_tags=False, threshold=5,
        dry_run=True, base_dir=base,
    )
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_compress(args)
    out = json.loads(buf.getvalue())
    assert out["status"] == "dry_run"
    assert open(af).read() == before


def test_below_threshold_noop(tmp_path):
    base = _setup(tmp_path, 3)
    args = types.SimpleNamespace(
        tag="", all_tags=True, threshold=5,
        dry_run=False, base_dir=base,
    )
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_compress(args)
    out = json.loads(buf.getvalue())
    assert out["compressed"] == 0
