"""Unit tests for harnish_py.progress — validate schema, loop-step, compress."""
import json
import types
import io
import contextlib
from pathlib import Path
from harnish_py.progress import _cmd_validate, _cmd_loop_step, _cmd_compress_progress


VALID_PROGRESS = {
    "metadata": {
        "prd": "docs/prd.md",
        "started_at": "2026-01-01T00:00:00",
        "last_session": "2026-01-01T01:00:00",
        "status": {"emoji": "🟢", "phase": 1, "task": "1-1", "label": "ok"},
    },
    "done": {"phases": []},
    "doing": {
        "task": {
            "id": "1-1", "title": "test", "started_at": "x",
            "current": "x", "next_action": "do something",
        }
    },
    "todo": {"phases": [{"phase": 1, "title": "P1",
                          "tasks": [{"id": "1-2", "title": "t2", "depends_on": []}]}]},
    "issues": [], "violations": [], "escalations": [],
    "stats": {"total_phases": 1, "completed_phases": 0,
              "total_tasks": 2, "completed_tasks": 0,
              "issues_count": 0, "violations_count": 0},
}


def _write_progress(tmp_path, data=None):
    p = tmp_path / "work.json"
    p.write_text(json.dumps(data or VALID_PROGRESS, ensure_ascii=False))
    return str(p)


def test_validate_pass(tmp_path):
    path = _write_progress(tmp_path)
    args = types.SimpleNamespace(progress_file=path)
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        result = _cmd_validate(args)
    assert result == 0


def test_validate_broken_json(tmp_path):
    p = tmp_path / "bad.json"
    p.write_text("{bad")
    args = types.SimpleNamespace(progress_file=str(p))
    result = _cmd_validate(args)
    assert result == 1


def test_validate_missing_keys(tmp_path):
    p = tmp_path / "empty.json"
    p.write_text("{}")
    args = types.SimpleNamespace(progress_file=str(p))
    result = _cmd_validate(args)
    assert result == 1


def test_loop_step_active(tmp_path, capsys):
    path = _write_progress(tmp_path)
    args = types.SimpleNamespace(progress_file=path, fmt="json")
    result = _cmd_loop_step(args)
    assert result == 0
    out = json.loads(capsys.readouterr().out)
    assert out["status"] == "ACTIVE"
    assert out["current_task"] == "1-1"


def test_loop_step_all_done(tmp_path, capsys):
    data = dict(VALID_PROGRESS)
    data = json.loads(json.dumps(data))  # deep copy
    data["doing"] = {"task": None}
    data["todo"] = {"phases": []}
    data["done"] = {"phases": [{"phase": 1, "title": "done", "compressed": False,
                                 "tasks": [{"id": "1-1", "title": "t", "result": "ok",
                                            "files_changed": []}]}]}
    path = _write_progress(tmp_path, data)
    args = types.SimpleNamespace(progress_file=path, fmt="json")
    _cmd_loop_step(args)
    out = json.loads(capsys.readouterr().out)
    assert out["status"] == "ALL_DONE"
