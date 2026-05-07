#!/usr/bin/env bats

load "setup.bash"

@test "drafti-architect SKILL.md Step 5 declares overwrite gate" {
  grep -q "overwrite" "$REPO_ROOT/skills/drafti-architect/SKILL.md"
  grep -q "new-slug" "$REPO_ROOT/skills/drafti-architect/SKILL.md"
  grep -q "already exists" "$REPO_ROOT/skills/drafti-architect/SKILL.md"
}

@test "drafti-architect SKILL.md Prohibited bans silent overwrite" {
  grep -q "Saving over an existing.*overwrite" "$REPO_ROOT/skills/drafti-architect/SKILL.md"
}

@test "drafti-architect SKILL.ko.md mirrors overwrite gate" {
  grep -q "overwrite" "$REPO_ROOT/skills/drafti-architect/SKILL.ko.md"
  grep -q "new-slug" "$REPO_ROOT/skills/drafti-architect/SKILL.ko.md"
  grep -q "이미 존재" "$REPO_ROOT/skills/drafti-architect/SKILL.ko.md"
}

@test "drafti-architect SKILL.ko.md Prohibited mirrors silent-overwrite ban" {
  grep -q "기존 \`docs/prd-\*\.md\`.*overwrite" "$REPO_ROOT/skills/drafti-architect/SKILL.ko.md"
}

@test "drafti-feature SKILL.md Step 7 declares overwrite gate" {
  grep -q "overwrite" "$REPO_ROOT/skills/drafti-feature/SKILL.md"
  grep -q "new-slug" "$REPO_ROOT/skills/drafti-feature/SKILL.md"
  grep -q "already exists" "$REPO_ROOT/skills/drafti-feature/SKILL.md"
}

@test "drafti-feature SKILL.md Prohibited bans silent overwrite" {
  grep -q "Saving over an existing.*overwrite" "$REPO_ROOT/skills/drafti-feature/SKILL.md"
}

@test "drafti-feature SKILL.ko.md mirrors overwrite gate" {
  grep -q "overwrite" "$REPO_ROOT/skills/drafti-feature/SKILL.ko.md"
  grep -q "new-slug" "$REPO_ROOT/skills/drafti-feature/SKILL.ko.md"
  grep -q "이미 존재" "$REPO_ROOT/skills/drafti-feature/SKILL.ko.md"
}

@test "drafti-feature SKILL.ko.md Prohibited mirrors silent-overwrite ban" {
  grep -q "기존 \`docs/prd-\*\.md\`.*overwrite" "$REPO_ROOT/skills/drafti-feature/SKILL.ko.md"
}
