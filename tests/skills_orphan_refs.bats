#!/usr/bin/env bats

# General orphan-reference guard:
# Every skills/*/references/*.md must be mentioned (by basename) in the
# corresponding SKILL.md (.md → SKILL.md, .ko.md → SKILL.ko.md). Catches the
# class of bug fixed in v0.1.1 (ralphi criteria-project.md was authored but
# never loaded from Step 3B).

load "setup.bash"

@test "no orphan references — every references/*.md is mentioned in SKILL.md" {
  local fail=0
  local fail_list=""
  for skill_dir in "$REPO_ROOT"/skills/*/; do
    local refs_dir="$skill_dir/references"
    [ -d "$refs_dir" ] || continue
    for ref in "$refs_dir"/*.md; do
      [ -f "$ref" ] || continue
      local base
      base="$(basename "$ref" .md)"
      local target ref_name
      if [[ "$base" == *.ko ]]; then
        target="$skill_dir/SKILL.ko.md"
        ref_name="${base%.ko}"
      else
        target="$skill_dir/SKILL.md"
        ref_name="$base"
      fi
      if ! grep -q "$ref_name" "$target" 2>/dev/null; then
        fail=1
        fail_list="$fail_list\n  $ref → not mentioned in $target"
      fi
    done
  done
  if [ "$fail" -ne 0 ]; then
    echo -e "Orphan references detected:$fail_list" >&2
    return 1
  fi
}
