"""Unit tests for harnish_py.io — atomic_write, jsonl_read, jsonl_append."""
import json
from pathlib import Path
from harnish_py.io import atomic_write, jsonl_read, jsonl_append, jsonl_rewrite


def test_atomic_write_creates_file(tmp_path):
    p = tmp_path / "sub" / "test.txt"
    atomic_write(p, "hello")
    assert p.read_text() == "hello"


def test_atomic_write_bytes(tmp_path):
    p = tmp_path / "bin.dat"
    atomic_write(p, b"\x00\x01\x02")
    assert p.read_bytes() == b"\x00\x01\x02"


def test_jsonl_read_missing_file(tmp_path):
    p = tmp_path / "no.jsonl"
    assert list(jsonl_read(p)) == []


def test_jsonl_read_empty_file(tmp_path):
    p = tmp_path / "empty.jsonl"
    p.write_text("")
    assert list(jsonl_read(p)) == []


def test_jsonl_append_and_read(tmp_path):
    p = tmp_path / "data.jsonl"
    jsonl_append(p, {"a": 1})
    jsonl_append(p, {"b": 2})
    records = list(jsonl_read(p))
    assert len(records) == 2
    assert records[0] == {"a": 1}
    assert records[1] == {"b": 2}


def test_jsonl_rewrite(tmp_path):
    p = tmp_path / "data.jsonl"
    jsonl_append(p, {"old": True})
    jsonl_rewrite(p, [{"new": True}])
    records = list(jsonl_read(p))
    assert len(records) == 1
    assert records[0] == {"new": True}


def test_jsonl_korean_roundtrip(tmp_path):
    p = tmp_path / "ko.jsonl"
    jsonl_append(p, {"title": "한글 테스트", "body": "내용"})
    records = list(jsonl_read(p))
    assert records[0]["title"] == "한글 테스트"
