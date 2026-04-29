"""Unit tests for harnish_py.cli — version guard, --version, unknown subcommand."""
import sys
import unittest.mock
from harnish_py import __version__
from harnish_py.cli import main


def test_version_guard_returns_4():
    with unittest.mock.patch.object(sys, "version_info", (3, 9)):
        result = main([])
        assert result == 4


def test_version_output(capsys):
    try:
        main(["--version"])
    except SystemExit as e:
        assert e.code == 0
    captured = capsys.readouterr()
    assert __version__ in captured.out


def test_unknown_subcommand_exits_1():
    try:
        result = main(["nonexistent-cmd"])
    except SystemExit as e:
        assert e.code == 1
