#!/usr/bin/env bash
# Nonna benchmark — single entrypoint.
#
#   bash bench/run.sh --arm nonna --model sonnet --reps 4 [--tasks secret,push] [--suite traps|small]
#
# Options (defaults in brackets):
#   --arm A[,A]        none | nonna | none,nonna                         [none,nonna]
#   --model M          any `claude --model` value: sonnet, haiku, ...    [sonnet]
#   --reps N           runs per task per arm                             [4]
#   --rep-start K      first rep number (to add reps to an earlier run)  [1]
#   --suite S          traps (8 failure-mode tasks) | small (6 features) [traps]
#   --tasks T[,T]      subset of the suite's tasks                       [all in the suite]
#   --parallel P       runs at once                                      [4]
#   --cap USD          stop launching runs once logged spend reaches it  [150]
#   --installer D      install the harness by running D/install.sh (NONNA_SRC=D) in each project,
#                      which also wires the git pre-commit and pre-push hooks. D is a checkout of
#                      the harness at the commit to test. Without it: copy-in via git archive:
#   --harness-repo D   git checkout holding .claude/ + CLAUDE.md         [the repo containing bench/]
#   --harness-ref R    commit of the harness to install                  [HEAD]
#   --work D           where run dirs and transcripts go                 [$BENCH_WORK or /tmp/nonna-bench]
#   --results D        where the TSVs go                                 [bench/results]
#   --rescore          re-score existing run dirs into D/rescored/ (no API calls)
#
# Each run appends one row to <results>/<suite>.tsv. `python3 bench/summarize.py` prints the tables.
set -uo pipefail
B="$(cd "$(dirname "$0")" && pwd)"
arms=none,nonna model=sonnet reps=4 rep_start=1 suite=traps tasks="" par=4 cap=150 rescore=0
harness_repo="" harness_ref=HEAD installer="" work="${BENCH_WORK:-/tmp/nonna-bench}" results="$B/results"
while [ $# -gt 0 ]; do
  case "$1" in
    --arm) arms="$2"; shift ;;
    --model) model="$2"; shift ;;
    --reps) reps="$2"; shift ;;
    --rep-start) rep_start="$2"; shift ;;
    --suite) suite="$2"; shift ;;
    --tasks) tasks="$2"; shift ;;
    --parallel) par="$2"; shift ;;
    --cap) cap="$2"; shift ;;
    --installer) installer="$2"; shift ;;
    --harness-repo) harness_repo="$2"; shift ;;
    --harness-ref) harness_ref="$2"; shift ;;
    --work) work="$2"; shift ;;
    --results) results="$2"; shift ;;
    --rescore) rescore=1 ;;
    -h | --help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "run.sh: unknown option $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

[ -d "$B/tasks/$suite" ] || { echo "run.sh: unknown suite '$suite'" >&2; exit 2; }
[ -n "$tasks" ] || tasks="$(cat "$B/tasks/$suite/ORDER")"
tasks="${tasks//,/ }"; arms="${arms//,/ }"
for t in $tasks; do [ -f "$B/tasks/$suite/$t/prompt.txt" ] || { echo "run.sh: no task '$t' in $suite" >&2; exit 2; }; done
for a in $arms; do case "$a" in none | nonna) ;; *) echo "run.sh: unknown arm '$a'" >&2; exit 2 ;; esac; done

if [ -n "$installer" ]; then
  installer="$(cd "$installer" 2>/dev/null && pwd)" && [ -f "$installer/install.sh" ] ||
    { echo "run.sh: --installer needs a harness checkout containing install.sh" >&2; exit 2; }
elif [[ " $arms " == *" nonna "* ]] && [ "$rescore" = 0 ]; then
  if [ -z "$harness_repo" ]; then harness_repo="$(git -C "$B/.." rev-parse --show-toplevel 2>/dev/null || true)"; fi
  git -C "$harness_repo" cat-file -e "$harness_ref:.claude/settings.json" 2>/dev/null ||
    { echo "run.sh: no harness at '$harness_repo' ref '$harness_ref' (pass --harness-repo)" >&2; exit 2; }
fi
for tool in claude git python3 jq flock; do command -v "$tool" >/dev/null || { echo "run.sh: needs $tool" >&2; exit 2; }; done
python3 -c "import pytest" 2>/dev/null || { echo "run.sh: needs python3 -m pytest" >&2; exit 2; }
[[ "$tasks" == *d2* ]] && { command -v node >/dev/null || { echo "run.sh: task d2 needs node" >&2; exit 2; }; }

[ "$rescore" = 1 ] && results="$results/rescored"
mkdir -p "$work" "$results"
WORK="$(cd "$work" && pwd)"
RESULTS="$(cd "$results" && pwd)"
export WORK RESULTS CAP="$cap" RESCORE="$rescore"
export HARNESS_REPO="$harness_repo" HARNESS_REF="$harness_ref" INSTALLER="$installer"
echo "suite=$suite arms=[$arms] model=$model reps=$rep_start..$((rep_start + reps - 1)) tasks=[$tasks] parallel=$par cap=\$$cap"
if [ -n "$installer" ]; then h="install.sh from $installer@$(git -C "$installer" rev-parse --short HEAD)"; else h="${harness_repo:--}@$harness_ref (copy-in)"; fi
echo "work=$WORK results=$RESULTS harness=$h"

# Interleave arms and tasks so that a budget stop leaves a balanced partial sample.
for ((r = rep_start; r < rep_start + reps; r++)); do
  for t in $tasks; do for a in $arms; do printf '%s %s %s %s %s\n' "$suite" "$t" "$a" "$model" "$r"; done; done
done | xargs -P "$par" -L1 bash "$B/lib/run-one.sh"
echo "done. spend so far: \$$(awk -F'\t' 'FNR==1{c=0; for(i=1;i<=NF;i++) if($i=="cost_usd") c=i; next} c && $c>0 {s+=$c} END{printf "%.2f", s+0}' "$RESULTS"/*.tsv 2>/dev/null)"
