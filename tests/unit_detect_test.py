"""Unit tests for harnish_py.detect — hook event routing."""
import io
import json
import os
import sys
import types
import unittest.mock
from pathlib import Path

import pytest


def _run_detect(stdin_data: str, base_dir: str, env: dict | None = None):
    """Helper: run _cmd_detect with given stdin and base_dir."""
    from harnish_py.detect import _cmd_detect

    env = env or {}
    fake_args = types.SimpleNamespace(base_dir=base_dir)
    with unittest.mock.patch.dict(os.environ, env):
        with unittest.mock.patch("sys.stdin", io.StringIO(stdin_data)):
            with unittest.mock.patch("sys.stdin.isatty", return_value=False):
                return _cmd_detect(fake_args)


def test_post_tool_use_reports_pending(tmp_path):
    """PostToolUse event triggers _report_pending (pending count visible)."""
    harnish_dir = tmp_path / ".harnish"
    harnish_dir.mkdir()

    session = "unit-detect-postuse"
    pending_file = Path(f"/tmp/harnish-pending-{session}.jsonl")
    pending_file.write_text('{"event":"x"}\n{"event":"y"}\n', encoding="utf-8")

    try:
        event = json.dumps({"hook_event_name": "PostToolUse", "session_id": session})
        captured = io.StringIO()
        with unittest.mock.patch("sys.stdout", captured):
            code = _run_detect(event, str(harnish_dir), {"CLAUDE_SESSION_ID": session})
        assert code == 0
        output = captured.getvalue()
        assert "2건" in output or "pending" in output
    finally:
        pending_file.unlink(missing_ok=True)


def test_post_tool_use_no_pending_silent(tmp_path):
    """PostToolUse with no pending file → exits 0 and prints nothing."""
    harnish_dir = tmp_path / ".harnish"
    harnish_dir.mkdir()

    session = "unit-detect-no-pending"
    pending_file = Path(f"/tmp/harnish-pending-{session}.jsonl")
    pending_file.unlink(missing_ok=True)

    event = json.dumps({"hook_event_name": "PostToolUse", "session_id": session})
    captured = io.StringIO()
    with unittest.mock.patch("sys.stdout", captured):
        code = _run_detect(event, str(harnish_dir), {"CLAUDE_SESSION_ID": session})
    assert code == 0
    assert captured.getvalue().strip() == ""
