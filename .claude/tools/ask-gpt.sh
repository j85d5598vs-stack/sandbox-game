#!/bin/zsh
# Sends a brief to GPT through the Codex CLI in read-only mode and prints GPT's final answer.
# Usage: .claude/tools/ask-gpt.sh <brief-file> [run-name]
#   The brief is a Markdown file. GPT can read the repo but cannot change it.
#   The answer is printed and also saved to .gpt-runs/<run-name>.md (git-ignored).
# Optional env: GPT_MODEL to pick a model (otherwise Codex's default is used).
set -e
ROOT="${0:A:h:h:h}"
BRIEF="$1"
NAME="${2:-run-$(date +%Y%m%d-%H%M%S)}"

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: Codex CLI is not installed. See https://github.com/openai/codex, then run 'codex login'." >&2
  exit 2
fi
if [[ -z "$BRIEF" || ! -f "$BRIEF" ]]; then
  echo "ERROR: give a brief file. Usage: ask-gpt.sh <brief-file> [run-name]" >&2
  exit 2
fi

mkdir -p "$ROOT/.gpt-runs"
OUT="$ROOT/.gpt-runs/$NAME.md"
MODEL_ARGS=()
[[ -n "$GPT_MODEL" ]] && MODEL_ARGS=(-m "$GPT_MODEL")

codex exec --sandbox read-only -C "$ROOT" "${MODEL_ARGS[@]}" \
  --output-last-message "$OUT" - < "$BRIEF" > "$ROOT/.gpt-runs/$NAME.log" 2>&1 \
  || { echo "ERROR: codex failed. Last lines of the log:" >&2; tail -20 "$ROOT/.gpt-runs/$NAME.log" >&2; exit 1; }

cat "$OUT"
