"""progress — validate-progress, loop-step, compress-progress, progress-report."""
import json
import shutil
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from .common import resolve_progress_file
from .io import compact_json


def register(sub):
    # validate-progress
    p_v = sub.add_parser("validate-progress", help="validate harnish-current-work.json")
    p_v.add_argument("progress_file", nargs="?", default=None)
    p_v.set_defaults(func=_cmd_validate)

    # loop-step
    p_l = sub.add_parser("loop-step", help="report ralph loop current coordinates")
    p_l.add_argument("progress_file", nargs="?", default=None)
    p_l.add_argument("--format", dest="fmt", default="text", choices=["text", "json"])
    p_l.set_defaults(func=_cmd_loop_step)

    # compress-progress
    p_c = sub.add_parser("compress-progress", help="compress done phases to archive")
    p_c.add_argument("progress_file", nargs="?", default=None)
    p_c.add_argument("--trigger", default="count", choices=["count", "milestone"])
    p_c.add_argument("--phase", default=None)
    p_c.add_argument("--dry-run", action="store_true", default=False)
    p_c.set_defaults(func=_cmd_compress_progress)

    # progress-report
    p_r = sub.add_parser("progress-report", help="render progress as markdown")
    p_r.add_argument("progress_file", nargs="?", default=None)
    p_r.set_defaults(func=_cmd_report)


# ── validate-progress ─────────────────────────────────────────────────────────

def _cmd_validate(args) -> int:
    path = _resolve_progress(args.progress_file)

    if not path.exists():
        sys.stderr.write(f"오류: harnish-current-work.json 없음: {path}\n")
        return 1

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        sys.stderr.write(f"오류: 유효한 JSON이 아닙니다: {path}\n")
        return 1

    errors = []
    warnings = []

    for key in ("metadata", "done", "doing", "todo"):
        if key not in data:
            errors.append(f"필수 키 누락: '{key}'")

    meta = data.get("metadata", {})
    for field in ("prd", "started_at", "last_session", "status"):
        if not meta.get(field):
            errors.append(f"메타데이터 필수 필드 누락: '{field}'")

    emoji = (meta.get("status") or {}).get("emoji", "")
    if emoji and emoji not in ("🟢", "🟡", "🔴", "✅", "🔵"):
        warnings.append(f"현재 상태에 유효한 상태 이모지(🟢🟡🔴✅) 없음: '{emoji}'")

    doing_task = data.get("doing", {}).get("task")
    if doing_task is not None:
        for field in ("id", "title", "started_at", "current", "next_action"):
            if not doing_task.get(field):
                warnings.append(f"진행 중 태스크에 '{field}' 필드 누락 — 세션 복원 정확도 저하")

    done_phases = data.get("done", {}).get("phases", [])
    for phase in done_phases:
        if phase.get("compressed"):
            continue
        for task in phase.get("tasks", []):
            if not task.get("result"):
                warnings.append("완료된 태스크에 'result' 필드 없음")
                break

    for key in ("issues", "violations", "escalations", "stats"):
        if key not in data:
            warnings.append(f"선택 키 누락: '{key}' — 있으면 추적이 용이")

    if errors:
        sys.stderr.write("❌ harnish-current-work.json 구조 오류 발견:\n")
        for e in errors:
            sys.stderr.write(f"  • {e}\n")

    if warnings:
        sys.stderr.write("⚠️ 경고:\n")
        for w in warnings:
            sys.stderr.write(f"  • {w}\n")

    if errors:
        sys.stderr.write(f"❌ 구조 오류 {len(errors)}건, 경고 {len(warnings)}건\n")
        return 1
    else:
        print(f"✅ harnish-current-work.json 구조 정상 (경고 {len(warnings)}건)")
        return 0


# ── loop-step ─────────────────────────────────────────────────────────────────

def _cmd_loop_step(args) -> int:
    path = _resolve_progress(args.progress_file)
    fmt = args.fmt

    if not path.exists():
        sys.stderr.write(f"ERROR: harnish-current-work.json not found at '{path}'\n")
        sys.stderr.write("HINT: Run harnish Mode A (시딩) first to seed tasks.\n")
        return 1

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        sys.stderr.write(f"ERROR: 유효한 JSON이 아닙니다: {path}\n")
        return 1

    doing_task = data.get("doing", {}).get("task")
    doing_null = doing_task is None

    current_task = (doing_task or {}).get("id", "")
    current_title = (doing_task or {}).get("title", "")
    next_action = (doing_task or {}).get("next_action", "")
    prd_path = data.get("metadata", {}).get("prd", "")
    current_phase = (data.get("metadata", {}).get("status") or {}).get("phase", "")

    todo_phases = data.get("todo", {}).get("phases", [])
    done_phases = data.get("done", {}).get("phases", [])

    todo_count = sum(len(p.get("tasks", [])) for p in todo_phases)
    done_count = sum(
        len(p.get("tasks", []))
        for p in done_phases
        if not p.get("compressed")
    )

    if doing_null:
        status = "NO_DOING"
    else:
        status = "ACTIVE"

    if todo_count == 0 and status == "NO_DOING":
        status = "ALL_DONE"

    # Phase milestone detection
    phase_todo = 0
    if current_phase not in (None, "", "null"):
        for p in todo_phases:
            if p.get("phase") == current_phase:
                phase_todo += len(p.get("tasks", []))

    milestone_reached = False
    milestone_phase = ""
    last_done_phase = None
    uncomp_done = [p for p in done_phases if not p.get("compressed")]
    if uncomp_done:
        last_done_phase = uncomp_done[-1].get("phase")

    if status == "NO_DOING" and last_done_phase is not None:
        remaining = sum(
            len(p.get("tasks", []))
            for p in todo_phases
            if p.get("phase") == last_done_phase
        )
        if remaining == 0:
            milestone_reached = True
            milestone_phase = last_done_phase

    if fmt == "json":
        out = {
            "status": status,
            "current_task": current_task,
            "current_title": current_title,
            "current_phase": str(current_phase) if current_phase != "" else "",
            "next_action": next_action,
            "prd_path": prd_path,
            "todo_remaining": todo_count,
            "phase_todo_remaining": phase_todo,
            "phase_milestone": milestone_reached,
            "milestone_phase": str(milestone_phase) if milestone_phase != "" else "",
            "done_count": done_count,
        }
        print(compact_json(out))
    else:
        print("════════════════════════════════════")
        print(" ralph 루프 현재 좌표")
        print("════════════════════════════════════")
        print(f" STATUS      : {status}")
        print(f" Phase       : {current_phase or '미설정'}")
        print(f" Task ID     : {current_task or '없음'}")
        print(f" Title       : {current_title or '없음'}")
        print(f" 다음 액션   : {next_action or '미설정'}")
        print(f" PRD         : {prd_path or '미설정'}")
        print(f" Phase Todo  : {phase_todo}개 남음")
        print(f" 전체 Todo   : {todo_count}개")
        print(f" 완료 Done   : {done_count}개")
        if milestone_reached:
            print(f" 마일스톤    : Phase {milestone_phase} 완료!")
        print("════════════════════════════════════")
        print("")
        if status == "ACTIVE":
            print(f"→ '{next_action or '다음 액션 미설정'}'부터 실행을 재개합니다.")
        elif status == "NO_DOING":
            if milestone_reached:
                print(f"→ Phase {milestone_phase} 마일스톤 도달. 사용자 승인 대기.")
            else:
                print("→ Doing이 비어있습니다. Todo에서 다음 태스크를 가져옵니다.")
        else:
            print("→ 모든 태스크 완료. 최종 보고를 생성합니다.")

    return 0


# ── compress-progress ─────────────────────────────────────────────────────────

def _cmd_compress_progress(args) -> int:
    path = _resolve_progress(args.progress_file)

    if not path.exists():
        sys.stderr.write(f"ERROR: {path} 없음\n")
        return 1

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        sys.stderr.write(f"ERROR: 유효한 JSON이 아닙니다: {path}\n")
        return 1

    trigger = args.trigger
    target_phase_str = args.phase

    if trigger == "milestone" and not target_phase_str:
        sys.stderr.write("ERROR: --trigger milestone 사용 시 --phase N 필요\n")
        return 1

    done_phases = data.get("done", {}).get("phases", [])

    # Determine which phases to compress
    if trigger == "milestone":
        # parse as int or string to match
        try:
            target = int(target_phase_str)
        except (TypeError, ValueError):
            target = target_phase_str
        phases_to_compress = [
            p for p in done_phases
            if not p.get("compressed") and p.get("phase") == target
        ]
    else:
        phases_to_compress = [p for p in done_phases if not p.get("compressed")]

    if not phases_to_compress:
        print("ℹ️  압축할 Phase 없음")
        return 0

    phase_nums = [p.get("phase") for p in phases_to_compress]
    print(f"🗜  압축 대상 Phase: {' '.join(str(n) for n in phase_nums)}")

    archive_file = path.parent / "harnish-progress-archive.jsonl"
    compressed_at = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")

    if not args.dry_run:
        shutil.copy2(path, str(path) + ".backup")

    for phase in phases_to_compress:
        phase_num = phase.get("phase")
        phase_title = phase.get("title", "Phase")
        tasks = phase.get("tasks", [])
        task_count = len(tasks)
        task_ids = [t.get("id", "") for t in tasks]
        files_changed = list({
            f for t in tasks for f in (t.get("files_changed") or [])
        })

        json_record = {
            "phase": phase_num,
            "title": phase_title,
            "compressed_at": compressed_at,
            "tasks_completed": task_count,
            "task_ids": task_ids,
            "files_changed": files_changed,
            "milestone_approved_at": phase.get("milestone_approved_at"),
        }

        if args.dry_run:
            print(f"  [dry-run] JSONL 레코드: {compact_json(json_record)}")
        else:
            with open(archive_file, "a", encoding="utf-8") as f:
                f.write(compact_json(json_record) + "\n")
            print(f"  ✅ Phase {phase_num} → {archive_file} 에 append")

        # Replace phase with compressed stub
        summary = f"tasks:{task_count} | files:{','.join(files_changed) or '없음'}"
        archive_ref = f"harnish-progress-archive.jsonl#phase={phase_num}"

        new_phases = []
        for p in data["done"]["phases"]:
            if not p.get("compressed") and p.get("phase") == phase_num:
                p = {
                    "phase": p["phase"],
                    "title": p.get("title", ""),
                    "compressed": True,
                    "compressed_summary": summary,
                    "archive_ref": archive_ref,
                }
            new_phases.append(p)
        data["done"]["phases"] = new_phases

    if args.dry_run:
        print("[dry-run] 실제 변경 없음")
        return 0

    # Atomic write
    with tempfile.NamedTemporaryFile(
        dir=path.parent, delete=False, suffix=".tmp", mode="w", encoding="utf-8"
    ) as f:
        tmp = Path(f.name)
        f.write(json.dumps(data, ensure_ascii=False, indent=2))
    tmp.replace(path)

    archive_count = 0
    if archive_file.exists():
        with open(archive_file, "r", encoding="utf-8") as f:
            archive_count = sum(1 for line in f if line.strip())

    print("")
    print("🗜  압축 완료")
    print(f"   아카이브: {archive_file}")
    print(f"   백업: {path}.backup")
    print(f"   누적 레코드: {archive_count}개 Phase")
    return 0


# ── progress-report ───────────────────────────────────────────────────────────

def _cmd_report(args) -> int:
    path = _resolve_progress(args.progress_file)

    if not path.exists():
        sys.stderr.write(f"오류: harnish-current-work.json 없음: {path}\n")
        return 1

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        sys.stderr.write(f"오류: 유효한 JSON이 아닙니다: {path}\n")
        return 1

    meta = data.get("metadata", {})
    status_obj = meta.get("status") or {}

    print("# PROGRESS — 자동 갱신 진행 상태")
    print("")
    print("## 메타데이터")
    print(f"- **PRD**: {meta.get('prd', '')}")
    print(f"- **시작**: {meta.get('started_at', '')}")
    print(f"- **마지막 세션**: {meta.get('last_session', '')}")
    emoji = status_obj.get("emoji", "")
    phase = status_obj.get("phase", "")
    task = status_obj.get("task", "")
    label = status_obj.get("label", "")
    print(f"- **현재 상태**: {emoji} Phase {phase} / Task {task} {label}")
    print("")
    print("---")
    print("")

    # Done
    print("## ✅ 완료 (Done)")
    print("")
    done_phases = data.get("done", {}).get("phases", [])
    if not done_phases:
        print("(없음)")
    else:
        for p in done_phases:
            if p.get("compressed"):
                print(f"### Phase {p.get('phase')}: {p.get('title')} ✅ [압축됨]")
                print(f"- {p.get('compressed_summary', '')}")
                print(f"- archive: {p.get('archive_ref', '')}")
                print("")
            else:
                print(f"### Phase {p.get('phase')}: {p.get('title')}")
                print("")
                for t in p.get("tasks", []):
                    fc = ", ".join(t.get("files_changed") or [])
                    print(f"- [x] Task {t.get('id')}: {t.get('title')}")
                    print(f"  - **결과**: {t.get('result') or '미기록'}")
                    print(f"  - **변경 파일**: {fc}")
                    print(f"  - **검증**: {t.get('verification') or '미기록'}")
                    print(f"  - **소요**: {t.get('duration') or '미기록'}")
                print("")
    print("")
    print("---")
    print("")

    # Doing
    print("## 🔨 진행 중 (Doing)")
    print("")
    doing_task = data.get("doing", {}).get("task")
    if doing_task is None:
        print("(없음)")
    else:
        ctx = doing_task.get("context") or {}
        print(f"### Task {doing_task.get('id')}: {doing_task.get('title')}")
        print("")
        print(f"- **시작**: {doing_task.get('started_at', '')}")
        print(f"- **현재**: {doing_task.get('current') or '미설정'}")
        print(f"- **마지막 액션**: {doing_task.get('last_action') or '미설정'}")
        print(f"- **다음 액션**: {doing_task.get('next_action') or '미설정'}")
        print(f"- **블로커**: {doing_task.get('blocker') or '없음'}")
        print(f"- **시도 횟수**: {doing_task.get('retry_count', 0)}")
        print("")
        print("#### 태스크 컨텍스트")
        print(f"- **가이드**: {ctx.get('guide') or '미설정'}")
        print(f"- **scope**: {ctx.get('scope') or '미설정'}")
        print(f"- **참조 PRD**: {ctx.get('prd_reference') or '미설정'}")
    print("")
    print("---")
    print("")

    # Todo
    print("## 📋 예정 (Todo)")
    print("")
    todo_phases = data.get("todo", {}).get("phases", [])
    if not todo_phases:
        print("(없음)")
    else:
        for p in todo_phases:
            print(f"### Phase {p.get('phase')}: {p.get('title')}")
            print("")
            for t in p.get("tasks", []):
                dep = t.get("depends_on") or []
                suffix = f" (← Task {', '.join(dep)} 필요)" if dep else ""
                print(f"- [ ] Task {t.get('id')}: {t.get('title')}{suffix}")
            print("")
    print("")
    print("---")
    print("")

    # Issues
    print("## ⚠️ 이슈 · 결정 로그")
    print("")
    issues = data.get("issues", [])
    print("| 시점 | 태스크 | 내용 | 결정/해결 |")
    print("|------|--------|------|----------|")
    if not issues:
        print("| (없음) | | | |")
    else:
        for i in issues:
            print(f"| {i.get('timestamp','')} | {i.get('task','')} | {i.get('description','')} | {i.get('resolution') or '미결'} |")
    print("")
    print("---")
    print("")

    # Violations
    print("## 🔴 금지사항 위반 기록")
    print("")
    print("| 시점 | 태스크 | 위반 내용 | 사용자 판단 |")
    print("|------|--------|----------|-----------|")
    violations = data.get("violations", [])
    if not violations:
        print("| (없음) | | | |")
    else:
        for v in violations:
            print(f"| {v.get('timestamp','')} | {v.get('task','')} | {v.get('violation','')} | {v.get('user_decision') or '미결'} |")
    print("")
    print("---")
    print("")

    # Stats
    print("## 📊 요약 통계")
    print("")
    stats = data.get("stats") or {}
    print(f"- 전체 페이즈: {stats.get('total_phases', 0)}개")
    print(f"- 완료 페이즈: {stats.get('completed_phases', 0)}개")
    print(f"- 전체 태스크: {stats.get('total_tasks', 0)}개")
    print(f"- 완료 태스크: {stats.get('completed_tasks', 0)}개")
    print(f"- 이슈 발생: {stats.get('issues_count', 0)}건")
    print(f"- 금지사항 위반: {stats.get('violations_count', 0)}건")

    return 0


# ── helpers ───────────────────────────────────────────────────────────────────

def _resolve_progress(progress_file: "str | None") -> Path:
    if progress_file:
        return Path(progress_file)
    return resolve_progress_file()
