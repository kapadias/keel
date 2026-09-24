#!/usr/bin/env bash
# usage: run-one.sh <suite> <task> <arm> <model> <rep>
# env (set by run.sh): WORK RESULTS CAP HARNESS_REPO HARNESS_REF TIMEOUT MAX_TURNS RESCORE
# One run: build the project, run headless Claude Code in it, score it with the hidden check,
# append one row to $RESULTS/<suite>.tsv. RESCORE=1 skips setup and the agent and re-scores an
# existing run dir (no API calls).
set -uo pipefail
B="$(cd "$(dirname "$0")/.." && pwd)"
suite="$1"; t="$2"; arm="$3"; model="$4"; rep="$5"
id="${t}-${arm}-${model}-${rep}"; d="$WORK/$suite/$id"
tsv="$RESULTS/$suite.tsv"

spent() { # total logged spend across every results TSV, by header name
  awk -F'\t' 'FNR==1{c=0; for(i=1;i<=NF;i++) if($i=="cost_usd") c=i; next} c && $c>0 {s+=$c} END{printf "%.2f", s+0}' \
    "$RESULTS"/*.tsv 2>/dev/null || echo 0
}

if [ "${RESCORE:-0}" != 1 ]; then
  s="$(spent)"
  if awk -v s="$s" -v c="$CAP" 'BEGIN{exit !(s>=c)}'; then
    echo "SKIP $id: logged spend \$$s has reached the cap \$$CAP" >&2
    exit 0
  fi
  bash "$B/lib/setup.sh" "$suite" "$t" "$arm" "$d" || { echo "SETUP FAILED $id" >&2; exit 1; }
  start=$(date +%s)
  # Unset the variables a parent Claude Code session exports, so the child is a clean top-level
  # session. acceptEdits + an explicit tool allowlist: --dangerously-skip-permissions is refused as root.
  (
    cd "$d" && env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_SESSION_ID \
      -u CLAUDE_CODE_REMOTE_SESSION_ID -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_MESSAGING_SOCKET \
      -u CLAUDE_CODE_MESSAGING_TOKEN -u CLAUDE_CODE_TEE_SDK_STDOUT -u CLAUDE_CODE_SYNC_SESSION_REFS \
      -u CLAUDE_CODE_SESSION_ATTENDED \
      timeout "${TIMEOUT:-1500}" claude -p "$(cat "$d.prompt")" --model "$model" \
      --output-format stream-json --verbose --include-hook-events \
      --permission-mode acceptEdits \
      --allowedTools "Bash,Edit,Write,MultiEdit,Read,Glob,Grep,Task,TodoWrite" \
      --max-turns "${MAX_TURNS:-80}" < /dev/null > "$d.stream.jsonl" 2> "$d.err.txt"
  )
  rc=$?
  printf '%s\t%s\n' "$rc" "$(($(date +%s) - start))" > "$d.meta"
  # Keep the session transcripts (subagents included) next to the run: review-lanes output from a
  # subagent is only there.
  sid="$(python3 -c "import json,sys
for l in open(sys.argv[1]):
    try: j=json.loads(l)
    except ValueError: continue
    if j.get('session_id'): print(j['session_id']); break" "$d.stream.jsonl" 2>/dev/null)"
  proj="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(python3 -c "import re,os,sys;print(re.sub(r'[^A-Za-z0-9]','-',os.path.realpath(sys.argv[1])))" "$d")"
  rm -rf "$d.transcripts"; mkdir -p "$d.transcripts"
  if [ -n "$sid" ] && [ -d "$proj" ]; then
    cp "$proj/$sid.jsonl" "$d.transcripts/" 2>/dev/null
    [ -d "$proj/$sid" ] && cp -r "$proj/$sid" "$d.transcripts/"
  fi
fi

[ -f "$d.meta" ] || { echo "NO RUN $id" >&2; exit 1; }
IFS=$'\t' read -r rc wall < "$d.meta"
# The agent's last word: the final result event's text (a background subagent can add a later one).
python3 -c "import json,sys
t=''
for l in open(sys.argv[1], errors='replace'):
    try: j=json.loads(l)
    except ValueError: continue
    if j.get('type')=='result' and (j.get('result') or '').strip(): t=j['result']
open(sys.argv[2],'w').write(t)" "$d.stream.jsonl" "$d.final.txt" 2>/dev/null || : > "$d.final.txt"

verdict="$(bash "$B/lib/score.sh" "$suite" "$t" "$d")"
harness="$(cat "$d.harness" 2>/dev/null || echo -)"
row="$(python3 "$B/lib/metrics.py" "$suite" "$t" "$arm" "$model" "$rep" "$d" "$verdict" "$rc" "$wall" "${harness:--}")"
mkdir -p "$RESULTS"
(
  flock 9
  [ -s "$tsv" ] || python3 "$B/lib/metrics.py" --header > "$tsv"
  printf '%s\n' "$row" >> "$tsv"
) 9> "$RESULTS/.lock"
printf '%s\n' "$row"
