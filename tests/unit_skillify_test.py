"""Unit tests for harnish_py.skillify — scaffold generation, triggers, references."""
import json
import types
import io
import contextlib
from pathlib import Path
from harnish_py.io import jsonl_append
from harnish_py.skillify import _cmd_skillify


def _setup(tmp_path, n=3):
    base = tmp_path / ".harnish"
    base.mkdir()
    af = base / "harnish-assets.jsonl"
    for i in range(n):
        jsonl_append(af, {
            "slug": f"f{i}", "type": "failure", "title": f"docker cache miss {i}",
            "tags": ["docker"], "date": "2026-01-01",
            "scope": "generic", "body": f"body content {i}",
            "context": "test", "session": "s",
        })
    return str(base)


def test_skill_md_created(tmp_path):
    base = _setup(tmp_path)
    out_dir = str(tmp_path / "skills-out")

    args = types.SimpleNamespace(
        tag="docker", skill_name="docker-patterns",
        output_dir=out_dir, base_dir=base,
    )
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_skillify(args)

    skill_md = Path(out_dir) / "docker-patterns" / "SKILL.md"
    assert skill_md.exists()
    content = skill_md.read_text()
    assert "name: docker-patterns" in content
    assert "version:" in content
    assert "description:" in content


def test_references_preserved(tmp_path):
    base = _setup(tmp_path)
    out_dir = str(tmp_path / "skills-out")

    args = types.SimpleNamespace(
        tag="docker", skill_name="docker-patterns",
        output_dir=out_dir, base_dir=base,
    )
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_skillify(args)

    refs = Path(out_dir) / "docker-patterns" / "references" / "source-assets.jsonl"
    assert refs.exists()
    lines = refs.read_text().strip().splitlines()
    assert len(lines) == 3


def test_trigger_extraction(tmp_path):
    base = _setup(tmp_path)
    out_dir = str(tmp_path / "skills-out")

    args = types.SimpleNamespace(
        tag="docker", skill_name="docker-patterns",
        output_dir=out_dir, base_dir=base,
    )
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        _cmd_skillify(args)

    content = (Path(out_dir) / "docker-patterns" / "SKILL.md").read_text()
    # "docker" should appear in triggers (base trigger)
    assert '"docker"' in content
