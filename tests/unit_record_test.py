"""Unit tests for harnish_py.record — slug dedup, required fields."""
import json
from harnish_py.io import jsonl_read, jsonl_append
from harnish_py.common import slugify


def test_slugify_ascii():
    assert slugify("Hello World") == "hello-world"


def test_slugify_korean():
    slug = slugify("한글 제목")
    assert len(slug) == 12  # md5 hex prefix


def test_slugify_dedup_counter():
    """Verify slug collision avoidance logic."""
    from harnish_py.record import _cmd_record
    import types
    import tempfile, os
    from pathlib import Path

    tmp = tempfile.mkdtemp()
    base = os.path.join(tmp, ".harnish")
    os.makedirs(base, exist_ok=True)
    Path(os.path.join(base, "harnish-assets.jsonl")).touch()
    Path(os.path.join(base, "harnish-current-work.json")).write_text("{}")

    # Record same title twice
    for _ in range(2):
        args = types.SimpleNamespace(
            type_="failure", tags="test", context="c", title="same-title",
            body="b", content="", body_file="", session_id="manual",
            scope="generic", base_dir=base, stdin=False,
        )
        _cmd_record(args)

    records = list(jsonl_read(os.path.join(base, "harnish-assets.jsonl")))
    slugs = [r["slug"] for r in records]
    assert len(set(slugs)) == 2  # no duplicates
    assert slugs[1].endswith("-2")
