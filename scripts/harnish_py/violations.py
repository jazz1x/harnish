"""check-violations — report violations and escalations from progress file."""
import json
import sys
from pathlib import Path
from .common import resolve_progress_file


def register(sub):
    p = sub.add_parser("check-violations", help="check violations and escalations")
    p.add_argument("progress_file", nargs="?", default=None)
    p.set_defaults(func=_cmd_violations)


def _cmd_violations(args) -> int:
    path = Path(args.progress_file) if args.progress_file else resolve_progress_file()

    if not path.exists():
        sys.stderr.write(f"ERROR: {path} not found\n")
        return 1

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        sys.stderr.write(f"ERROR: invalid JSON: {path}\n")
        return 1

    violations = data.get("violations") or []
    escalations = data.get("escalations") or []

    print(f"위반 기록: {len(violations)}건")
    print(f"에스컬레이션: {len(escalations)}건")

    if violations:
        print("")
        print("── 위반 내역 ──")
        for v in violations:
            ts = v.get("timestamp", "")
            task = v.get("task", "")
            viol = v.get("violation", "")
            decision = v.get("user_decision") or "미결"
            print(f"  {ts} | Task {task} | {viol} | 판단: {decision}")

    if escalations:
        print("")
        print("── 에스컬레이션 내역 ──")
        for e in escalations:
            ts = e.get("timestamp", "")
            task = e.get("task", "")
            blocked = e.get("blocked_at", "")
            print(f"  {ts} | Task {task} | {blocked}")

    return 0
