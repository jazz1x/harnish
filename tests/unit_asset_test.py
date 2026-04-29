"""Unit tests for harnish_py.asset — type metadata, abstract/localize."""
from harnish_py.asset import VALID_TYPES, TYPE_EXTRAS, _find_by_slug, _append_record
from harnish_py.io import jsonl_read, jsonl_append


def test_valid_types_complete():
    assert VALID_TYPES == {"failure", "pattern", "guardrail", "snippet", "decision"}


def test_type_extras_keys():
    for t in VALID_TYPES:
        assert t in TYPE_EXTRAS


def test_find_by_slug(tmp_path):
    p = tmp_path / "assets.jsonl"
    jsonl_append(p, {"slug": "abc", "title": "found"})
    jsonl_append(p, {"slug": "xyz", "title": "other"})
    result = _find_by_slug(p, "abc")
    assert result is not None
    assert result["title"] == "found"


def test_find_by_slug_missing(tmp_path):
    p = tmp_path / "assets.jsonl"
    jsonl_append(p, {"slug": "abc"})
    assert _find_by_slug(p, "nope") is None


def test_append_record_creates_file(tmp_path):
    p = tmp_path / "assets.jsonl"
    p.touch()
    _append_record(p, {"slug": "new", "type": "pattern"})
    records = list(jsonl_read(p))
    assert len(records) == 1
    assert records[0]["slug"] == "new"


def test_append_record_preserves_existing(tmp_path):
    p = tmp_path / "assets.jsonl"
    jsonl_append(p, {"slug": "old"})
    _append_record(p, {"slug": "new"})
    records = list(jsonl_read(p))
    assert len(records) == 2
    assert records[0]["slug"] == "old"
    assert records[1]["slug"] == "new"
