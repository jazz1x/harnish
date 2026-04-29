"""init-assets — initialize .harnish/ directory structure."""
import sys
from pathlib import Path
from .common import resolve_base_dir


def register(sub):
    p = sub.add_parser("init-assets", help="initialize .harnish/ directory")
    p.add_argument("--base-dir", dest="base_dir", default=None)
    p.add_argument("--quiet", action="store_true", default=False)
    p.set_defaults(func=_cmd_init)


def _cmd_init(args) -> int:
    return init_assets(base_dir=args.base_dir, quiet=args.quiet)


def init_assets(base_dir: "str | None" = None, quiet: bool = False) -> int:
    base = resolve_base_dir(base_dir)
    base.mkdir(parents=True, exist_ok=True)

    asset_file = base / "harnish-assets.jsonl"
    legacy_file = base / "harnish-rag.jsonl"
    work_file = base / "harnish-current-work.json"

    # Legacy auto-migration (idempotent)
    if legacy_file.exists() and not asset_file.exists():
        legacy_file.rename(asset_file)
        if not quiet:
            print("ℹ legacy harnish-rag.jsonl → harnish-assets.jsonl 자동 이전")

    if not asset_file.exists():
        asset_file.touch()

    if not work_file.exists():
        work_file.write_text("{}\n", encoding="utf-8")

    if not quiet:
        print(f"✓ .harnish/ 초기화 완료 ({base})")

    return 0
