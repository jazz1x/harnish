"""CLI entry point — argparse subcommand router.

Pattern: each module exposes register(sub) which adds its own subparser.
"""
import argparse
import sys
from typing import Optional, List
from . import __version__


class _Parser(argparse.ArgumentParser):
    """ArgumentParser that exits with code 1 (not 2) on bad args."""
    def error(self, message: str) -> None:
        self.print_usage(sys.stderr)
        self.exit(1, f"error: {message}\n")


def main(argv: Optional[List[str]] = None) -> int:
    """CLI entry point. Returns exit code."""
    if sys.version_info < (3, 14):
        sys.stderr.write("python3>=3.14 required\n")
        return 4

    parser = _Parser(
        prog="harnish_py",
        description="harnish — autonomous implementation engine",
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {__version__}"
    )

    sub = parser.add_subparsers(
        dest="command", required=True, parser_class=_Parser
    )

    # Lazy imports — each module registers its own subparser
    from . import (
        record, query, init, compress, promote, detect,
        skillify, quality, thresholds, purge, migrate,
        progress, violations, asset,
    )
    record.register(sub)
    query.register(sub)
    init.register(sub)
    compress.register(sub)
    promote.register(sub)
    detect.register(sub)
    skillify.register(sub)
    quality.register(sub)
    thresholds.register(sub)
    purge.register(sub)
    migrate.register(sub)
    progress.register(sub)
    violations.register(sub)
    asset.register(sub)  # abstract-asset + localize-asset

    args = parser.parse_args(argv)
    return args.func(args)
