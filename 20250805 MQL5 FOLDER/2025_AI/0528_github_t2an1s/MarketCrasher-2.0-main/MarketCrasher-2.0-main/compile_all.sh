#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# compile_all.sh
# Portable compile script for MetaTrader 5 EAs inside CrossOver.
#   • Never aborts early; keeps compiling the rest even when one fails
#   • Bash-3.2 compatible (macOS stock shell)
#   • Stores every compiler log in build_logs/
#   • Prints err | warn table, exits 0 only when all EAs have zero errors
# ---------------------------------------------------------------------------

set -u                # NO '-e' → keep going after individual failures
shopt -s nullglob

# ---- AUTOMATIC BACK-END SELECTION -----------------------------------------
if [[ -z "${CX:-}" || ! -x "$CX" ]]; then
# CrossOver not present → fall back to Wine + portable MT5
CX="wine"
  : "${METAEDITOR_EXE:?run ci-setup.sh first}"
EXE="$(winepath -w "$METAEDITOR_EXE")"
fiBOT="MT5"
EXE="C:/Program Files/MetaTrader 5/metaeditor64.exe"
INC="/include:\"$PWD/MQL5/Include\""        # add more /include:"…" if you need

LOG_DIR="build_logs"
mkdir -p "$LOG_DIR"

##############################################################################
# 1  Decide which .mq5 files to compile
##############################################################################
FILES=()

if [[ $# -gt 0 && -n "$1" ]]; then
  FILES=( "$@" )                     # glob or list passed from workflow input
else
  while IFS= read -r -d '' f; do
    FILES+=( "$f" )
  done < <(find . -type f -name '*.mq5' -print0 | sort -z)
fi

[[ ${#FILES[@]} -gt 0 ]] || { echo "❌ no MQ5 files found"; exit 1; }

##############################################################################
# 2  Compile loop
##############################################################################
status=0
summary=$(mktemp)

for src in "${FILES[@]}"; do
  # one log per EA, slashes replaced with _
  flat=${src//[\/ ]/_}
  log="${LOG_DIR}/${flat}.log"

  echo "::group::Compiling $src"
  "$CX" --bottle "$BOT" --wait -- \
        "$EXE" $INC /compile:"$PWD/$src" /log:"$PWD/$log" || true
  echo "::endgroup::"

  # ---- read totals from MetaEditor "Result : N error(s), M warning(s)" line
  result_line=$(grep -E 'Result[[:space:]]*:' "$log" | tail -n 1)
  errs=$(echo "$result_line" | grep -Eo '[0-9]+ error'   | awk '{print $1+0}')
  warns=$(echo "$result_line" | grep -Eo '[0-9]+ warning'| awk '{print $1+0}')
  errs=${errs:-0}; warns=${warns:-0}

  printf "%-60s | %3d | %3d\n" "$src" "$errs" "$warns" >> "$summary"
  [[ $errs -eq 0 ]] || status=1

  # optional: show first 10 + final result line for quick glance
  echo "----- head of $log -----"
  head -n 10 "$log"
  echo "----- $result_line -----"
done

##############################################################################
# 3  Print summary & exit
##############################################################################
echo -e "\n================ build summary ============================="
printf "%-60s | %s | %s\n" "file" "err" "warn"
printf -- "------------------------------------------------------------+-----+-----\n"
cat "$summary"
printf -- "------------------------------------------------------------+-----+-----\n"

if [[ $status -eq 0 ]]; then
  echo "✅ all sources compiled with 0 errors"
else
  echo "❌ one or more sources failed – see logs in $LOG_DIR/"
fi

exit $status
