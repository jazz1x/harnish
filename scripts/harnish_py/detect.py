"""detect-asset — Claude Code hook entry point.

Reads hook JSON from stdin, routes on hook_event_name.
Must exit 0 even on errors (hook silently fails policy).
"""
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from .common import resolve_base_dir, resolve_asset_file
from .io import compact_json


def register(sub):
    p = sub.add_parser("detect-asset", help="hook event router (reads stdin)")
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.set_defaults(func=_cmd_detect)


def _cmd_detect(args) -> int:
    try:
        return _run(args.base_dir)
    except Exception:
        return 0  # hooks must never block


def _run(base_dir: "str | None") -> int:
    base = resolve_base_dir(base_dir)
    asset_file = base / "harnish-assets.jsonl"

    # .harnish/ not present → silent no-op
    if not base.is_dir():
        return 0

    # Session hash
    session_hash = os.environ.get("CLAUDE_SESSION_ID") or _pid_hash()
    pending_file = Path(f"/tmp/harnish-pending-{session_hash}.jsonl")

    # Read stdin
    raw = ""
    if not sys.stdin.isatty():
        try:
            raw = sys.stdin.read()
        except Exception:
            raw = ""

    # Non-JSON stdin → report pending count only
    if not raw:
        _report_pending(pending_file)
        return 0

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        _report_pending(pending_file)
        return 0

    event = data.get("hook_event_name", "")
    tool_name = data.get("tool_name", "")
    tool_output = data.get("tool_output", "")
    session_id = data.get("session_id", "")

    # ── Stop event ────────────────────────────────────────────────────────────
    if event == "Stop":
        if asset_file.exists() and asset_file.stat().st_size > 0:
            try:
                from .thresholds import check_thresholds_str
                thresh_out = check_thresholds_str(base_dir=str(base))
                if thresh_out:
                    print(thresh_out)
            except Exception:
                pass

        if pending_file.exists() and pending_file.stat().st_size > 0:
            pending_count = _count_lines(pending_file)
            try:
                from .promote import promote_pending
                result = promote_pending(session_hash, str(base), dry_run=False)
                promoted = result.get("promoted", 0)
                dedup = result.get("deduplicated", 0)
                if promoted > 0:
                    print(f"harnish: 세션 종료 — pending {pending_count}건 → {promoted}건 자산 승격 (중복 {dedup}건 통합)")
                else:
                    print(f"harnish: 세션 종료 — {pending_count}건 pending 처리 실패")
            except Exception:
                print(f"harnish: 세션 종료 — {pending_count}건 pending 처리 실패")
            try:
                pending_file.unlink(missing_ok=True)
            except Exception:
                pass

        # Clean up stale pending files (>7 days)
        try:
            import glob
            import time
            cutoff = time.time() - 7 * 86400
            for stale in glob.glob("/tmp/harnish-pending-*.jsonl"):
                try:
                    if os.path.getmtime(stale) < cutoff:
                        os.unlink(stale)
                except Exception:
                    pass
        except Exception:
            pass

        return 0

    # ── PostToolUseFailure ────────────────────────────────────────────────────
    if event == "PostToolUseFailure":
        noise = re.compile(
            r"No such file|permission denied|command not found|"
            r"not a directory|Is a directory|syntax error near|unexpected token",
            re.IGNORECASE,
        )
        if not tool_output or noise.search(tool_output):
            return 0

        # Trim pending file if too large
        if pending_file.exists():
            count = _count_lines(pending_file)
            if count >= 500:
                lines = pending_file.read_text(encoding="utf-8").splitlines()
                pending_file.write_text(
                    "\n".join(lines[-250:]) + "\n", encoding="utf-8"
                )

        # Truncate output if too long
        if len(tool_output) > 2000:
            tool_output = tool_output[:2000] + "...(truncated)"

        from datetime import datetime
        pending_record = {
            "event": event,
            "tool": tool_name,
            "output": tool_output,
            "session": session_id,
            "date": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        }
        with open(pending_file, "a", encoding="utf-8") as f:
            f.write(compact_json(pending_record) + "\n")
        count = _count_lines(pending_file)
        print(f"harnish: 에러 감지 → pending ({count}건)")
        return 0

    # ── PostToolUse ───────────────────────────────────────────────────────────
    if event == "PostToolUse":
        _report_pending(pending_file)
        return 0

    return 0


def _pid_hash() -> str:
    return hashlib.md5(str(os.getpid()).encode()).hexdigest()[:8]


def _count_lines(path: Path) -> int:
    count = 0
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                count += 1
    return count


def _report_pending(pending_file: Path) -> None:
    if pending_file.exists() and pending_file.stat().st_size > 0:
        count = _count_lines(pending_file)
        print(f"harnish: {count}건 pending 자산 감지됨")
