"""Unit tests for harnish_py.query — tag filtering, type filtering, formats."""
import json
import os
import tempfile
from pathlib import Path
from harnish_py.io import jsonl_append
from harnish_py.query import query_assets


def _setup(tmp_path):
    base = tmp_path / ".harnish"
    base.mkdir()
    af = base / "harnish-assets.jsonl"
    jsonl_append(af, {"slug": "a", "type": "failure", "title": "err",
                      "tags": ["api", "retry"], "date": "2026-01-01",
                      "scope": "generic", "body": "body-a", "context": "ctx"})
    jsonl_append(af, {"slug": "b", "type": "pattern", "title": "pat",
                      "tags": ["db"], "date": "2026-01-02",
                      "scope": "generic", "body": "body-b", "context": "ctx"})
    jsonl_append(af, {"slug": "c", "type": "failure", "title": "err2",
                      "tags": ["api"], "date": "2026-01-03",
                      "scope": "generic", "body": "body-c", "context": "ctx",
                      "compressed": True})
    return str(base)


def test_tag_filter_or(tmp_path, capsys):
    base = _setup(tmp_path)
    query_assets(tags="api", fmt="json", base_dir=base)
    out = json.loads(capsys.readouterr().out)
    assert out["count"] == 1
    assert out["results"][0]["slug"] == "a"


def test_type_filter(tmp_path, capsys):
    base = _setup(tmp_path)
    query_assets(tags="api,db", types="pattern", fmt="json", base_dir=base)
    out = json.loads(capsys.readouterr().out)
    assert out["count"] == 1
    assert out["results"][0]["type"] == "pattern"


def test_compressed_excluded(tmp_path, capsys):
    base = _setup(tmp_path)
    query_assets(tags="api", fmt="json", base_dir=base)
    out = json.loads(capsys.readouterr().out)
    slugs = [r["slug"] for r in out["results"]]
    assert "c" not in slugs


def test_empty_store(tmp_path, capsys):
    base = tmp_path / ".harnish"
    base.mkdir()
    (base / "harnish-assets.jsonl").touch()
    query_assets(tags="any", fmt="text", base_dir=str(base))
    assert "검색 결과 없음" in capsys.readouterr().out


def test_inject_format(tmp_path, capsys):
    base = _setup(tmp_path)
    query_assets(tags="api", fmt="inject", base_dir=base)
    out = capsys.readouterr().out
    assert "관련 자산 (asset-recorder)" in out
    assert "err" in out


def test_access_count_incremented(tmp_path, capsys):
    base = _setup(tmp_path)
    af = tmp_path / ".harnish" / "harnish-assets.jsonl"
    # First query — access_count should go from 0 to 1
    query_assets(tags="api", fmt="json", base_dir=base)
    capsys.readouterr()
    from harnish_py.io import jsonl_read
    records = {r["slug"]: r for r in jsonl_read(af)}
    assert records["a"].get("access_count", 0) == 1
    assert records["a"]["last_accessed_at"] != ""
    # Second query — access_count should be 2
    query_assets(tags="api", fmt="json", base_dir=base)
    capsys.readouterr()
    records2 = {r["slug"]: r for r in jsonl_read(af)}
    assert records2["a"].get("access_count") == 2
