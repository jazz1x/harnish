#!/usr/bin/env bats

load "setup.bash"

@test "ralphi SKILL.md Step 3B loads criteria-project" {
  grep -q "criteria-project" "$REPO_ROOT/skills/ralphi/SKILL.md"
  grep -q "directory-scope counterpart" "$REPO_ROOT/skills/ralphi/SKILL.md"
}

@test "ralphi SKILL.ko.md Step 3B mirrors criteria-project mapping" {
  grep -q "criteria-project" "$REPO_ROOT/skills/ralphi/SKILL.ko.md"
  grep -q "디렉토리 스코프 카운터파트" "$REPO_ROOT/skills/ralphi/SKILL.ko.md"
}

@test "ralphi criteria-project.md exists (no longer orphan)" {
  [ -f "$REPO_ROOT/skills/ralphi/references/criteria-project.md" ]
  [ -f "$REPO_ROOT/skills/ralphi/references/criteria-project.ko.md" ]
}
