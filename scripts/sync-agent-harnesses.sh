#!/usr/bin/env bash
# Mirror the Mac's agent harness setup onto the desktop's `agent` user:
# global rules, skills (aihub repos, ~/.agents/skills, per-harness extras),
# Claude/Codex/Pi/Antigravity config, the kimi/deepseek/glm wrappers, and
# credentials. Safe to re-run; the Mac is the source of truth.
#
#   scripts/sync-agent-harnesses.sh            # everything
#   NO_CREDS=1 scripts/sync-agent-harnesses.sh # skip logins and API keys
set -euo pipefail

DEST=nixos-btw-agent
RHOME=/home/agent
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cd "$HOME"

rs() { rsync -a --exclude .DS_Store "$@"; }
to_remote() { sed "s#^$HOME/#$RHOME/#; s#^$HOME\$#$RHOME#"; }

echo "== trees"
ssh "$DEST" "mkdir -p ~/Workspace ~/.claude/skills ~/.codex/skills ~/.gemini/config/skills ~/.pi/agent/skills ~/.local/bin ~/.config/synthetic ~/.local/share/agent-skills"
rs --delete Workspace/aihub/ "$DEST:Workspace/aihub/"
rs --delete --exclude skills/cua-driver .agents/ "$DEST:.agents/"
rs Workspace/research/.claude/skills/sentiment-research "$DEST:.local/share/agent-skills/"
rs .claude/agents/ "$DEST:.claude/agents/"
rs --exclude sessions --exclude subagent-runs --exclude backups \
  --exclude trust.json --exclude auth.json --exclude mcp-auth.json \
  --exclude npm/node_modules --exclude skills --exclude AGENTS.md --exclude APPEND_SYSTEM.md \
  .pi/agent/ "$DEST:.pi/agent/"

# Real (non-symlink) skill dirs, minus Mac-only ones.
real_dirs() { # dir, exclude-regex
  find "$1" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | grep -Ev "/($2)\$" || true
}
real_dirs .claude/skills 'ma3|synced' | rs --files-from=- -r . "$DEST:"
real_dirs .codex/skills 'adopt-c-bounds-safety|audit-xcode-security-settings|device-interaction|swift-.*|swiftui-.*|uikit-app-modernization' \
  | rs --files-from=- -r . "$DEST:"
real_dirs .pi/agent/skills 'none' | rs --files-from=- -r . "$DEST:"

echo "== symlinks"
# One "link<TAB>target" per line, with Mac paths rewritten for the desktop.
{
  for d in .claude/skills .codex/skills .gemini/config/skills .pi/agent/skills; do
    for l in "$d"/*; do
      [ -L "$l" ] || continue
      t=$(readlink "$l")
      case "$t" in
        *"/.cua-driver/"*) continue ;;
        "$HOME/Workspace/research/.claude/skills/"*) t="$HOME/.local/share/agent-skills/${t##*/}" ;;
      esac
      [[ "$t" = /* ]] && t=$(to_remote <<<"$t")
      printf '%s\t%s\n' "$l" "$t"
    done
  done
  for l in .claude/CLAUDE.md .codex/AGENTS.md .gemini/GEMINI.md .pi/agent/AGENTS.md .pi/agent/APPEND_SYSTEM.md; do
    [ -L "$l" ] && printf '%s\t%s\n' "$l" "$(readlink "$l" | to_remote)"
  done
} > "$STAGE/links.tsv"
scp -q "$STAGE/links.tsv" "$DEST:/tmp/agent-links.tsv"
ssh "$DEST" bash -s <<'EOF'
cd ~
while IFS=$'\t' read -r link target; do
  if [ -e "$link" ] && [ ! -L "$link" ]; then echo "skip (real dir): $link"; continue; fi
  ln -sfn "$target" "$link"
done < /tmp/agent-links.tsv
rm /tmp/agent-links.tsv
broken=$(find .claude/skills .codex/skills .gemini/config/skills .pi/agent/skills -maxdepth 1 -xtype l)
[ -z "$broken" ] || { echo "broken links:"; echo "$broken"; }
EOF

echo "== config"
# Claude: drop Mac hooks (iTerm2 cc-status) and Mac-path denies.
jq --arg h "$RHOME" '
  del(.hooks)
  | .permissions.deny |= map(select(test("MALightingTechnology") | not) | gsub("/Users/dwitt"; $h) | gsub("/Users"; "/home"))
' .claude/settings.json > "$STAGE/claude-settings.json"
jq '{outputStyle}' .claude/settings.local.json > "$STAGE/claude-settings.local.json"
scp -q "$STAGE/claude-settings.json" "$DEST:.claude/settings.json"
scp -q "$STAGE/claude-settings.local.json" "$DEST:.claude/settings.local.json"

# Codex: portable subset of config.toml (no .app paths, Mac projects or bundled plugins).
python3 - "$STAGE/codex-config.toml" <<'PY'
import sys, tomllib, json, pathlib
src = tomllib.loads((pathlib.Path.home() / ".codex/config.toml").read_text())
def q(v): return json.dumps(v)
out = []
for k in ("model", "model_reasoning_effort", "approval_policy", "sandbox_mode", "service_tier", "memories"):
    if k in src: out.append(f"{k} = {q(src[k])}")
for table in ("agents", "features"):
    if table in src:
        out.append(f"\n[{table}]")
        out += [f"{k} = {q(v)}" for k, v in src[table].items() if not isinstance(v, dict)]
for name in ("context7", "openaiDeveloperDocs"):
    s = src.get("mcp_servers", {}).get(name)
    if s:
        out.append(f"\n[mcp_servers.{name}]")
        out += [f"{k} = {q(v)}" for k, v in s.items() if not isinstance(v, dict)]
for name, m in src.get("marketplaces", {}).items():
    if str(m.get("source", "")).startswith(("http", "git")):
        out.append(f"\n[marketplaces.{q(name)}]")
        out += [f"{k} = {q(v)}" for k, v in m.items() if not isinstance(v, dict)]
for pid, p in src.get("plugins", {}).items():
    if pid.split("@")[-1] in ("openai-curated", "i-have-adhd") and "macos" not in pid:
        out.append(f"\n[plugins.{q(pid)}]")
        out += [f"{k} = {q(v)}" for k, v in p.items() if not isinstance(v, dict)]
pathlib.Path(sys.argv[1]).write_text("\n".join(out) + "\n")
PY
scp -q "$STAGE/codex-config.toml" "$DEST:.codex/config.toml"

# kimi/deepseek/glm wrappers: GNU timeout, key from a file, pi from PATH.
sed -e 's/command -v gtimeout >\/dev\/null || fail 2 "gtimeout missing (brew install coreutils)"/TIMEOUT=$(command -v gtimeout || command -v timeout) || fail 2 "timeout missing"/' \
    -e 's/gtimeout -k 10/"$TIMEOUT" -k 10/' \
    -e 's#KEY=${SYNTHETIC_API_KEY:-$(security find-generic-password -a "$USER" -s synthetic-api-key -w 2>/dev/null)}#KEY=${SYNTHETIC_API_KEY:-$(cat ~/.config/synthetic/api-key 2>/dev/null || security find-generic-password -a "$USER" -s synthetic-api-key -w 2>/dev/null)}#' \
    -e "s#/Users/dwitt#$RHOME#g" \
    "$(readlink -f .local/bin/kimi)" > "$STAGE/kimi"
sed -e 's#^for p in "$HOME"/.nvm/versions/node/\*/bin/pi; do PI=$p; done#PI=$(command -v pi)#' \
    -e 's#pi not found under ~/.nvm#pi not on PATH#' \
    "$(readlink -f .local/bin/glm)" > "$STAGE/glm"
grep -q 'gtimeout -k' "$STAGE/kimi" && { echo "kimi patch failed" >&2; exit 1; }
grep -q '.nvm/versions' "$STAGE/glm" && { echo "glm patch failed" >&2; exit 1; }
scp -q "$STAGE/kimi" "$STAGE/glm" "$DEST:.local/bin/"
ssh "$DEST" 'cd ~/.local/bin && chmod +x kimi glm && ln -sfn kimi deepseek
  sed -i "s/mktemp -t \(kimi\|deepseek\)-answer)/mktemp -t \1-answer.XXXXXX)/" ~/.claude/agents/*.md'

if [ -z "${NO_CREDS:-}" ]; then
  echo "== credentials"
  umask 077
  security find-generic-password -s "Claude Code-credentials" -w > "$STAGE/claude-creds.json"
  jq -r '.providers.synthetic.apiKey' .pi/agent/models.json > "$STAGE/synthetic-key"
  gh auth token > "$STAGE/gh-token"
  scp -q "$STAGE/claude-creds.json" "$DEST:.claude/.credentials.json"
  scp -q .codex/auth.json "$DEST:.codex/auth.json"
  scp -q "$STAGE/synthetic-key" "$DEST:.config/synthetic/api-key"
  scp -q "$STAGE/gh-token" "$DEST:/tmp/gh-token"
  ssh "$DEST" bash -l <<'EOF'
chmod 600 ~/.claude/.credentials.json ~/.codex/auth.json ~/.config/synthetic/api-key
gh auth login --with-token < /tmp/gh-token; rm -f /tmp/gh-token
EOF
fi

echo "== installs"
ssh "$DEST" bash -l <<'EOF'
set -e
cd ~/.pi/agent/npm && npm install --no-fund --no-audit --loglevel=error
for m in anthropics/claude-plugins-official ayghri/i-have-adhd openai/codex-plugin-cc; do
  claude plugin marketplace add "$m" >/dev/null 2>&1 || true
done
for p in codex@openai-codex i-have-adhd@i-have-adhd frontend-design@claude-plugins-official \
         typescript-lsp@claude-plugins-official code-simplifier@claude-plugins-official \
         claude-md-management@claude-plugins-official code-review@claude-plugins-official \
         commit-commands@claude-plugins-official feature-dev@claude-plugins-official; do
  claude plugin install "$p" >/dev/null 2>&1 || echo "plugin install failed: $p"
done
EOF
echo "done"
