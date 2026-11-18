#!/usr/bin/env bash
# Stores eval results in the Harness File Store (best effort, never fails the step):
#   1) a running CSV ledger, one row per run:         agent_eval_<pipeline>
#   2) one JSON detail bundle per run:                 agent_eval_run_<execution id>
# Same API pattern and secret as your Agent Usage Report step.
set -uo pipefail
D=/harness/preflight
F=$D/output.json; C=$D/eval_code.json; J=$D/judge.json; X=$D/eval_explanation.md; P=$D/plan.md

jfile() { if [ -s "$1" ] && jq -e . "$1" >/dev/null 2>&1; then jq -c . "$1"; else echo null; fi; }
rf()    { if [ -f "$1" ]; then echo "$1"; else : > /tmp/empty.txt; echo /tmp/empty.txt; fi; }
clean() { case "${1:-}" in ""|"<+"*) printf '%s' "$2" ;; *) printf '%s' "$1" | tr ',\n' '; ' ;; esac; }

ZONE=NONE; [ -s "$F" ] && ZONE=$(jq -r '.score.zone // "NONE"' "$F" 2>/dev/null || echo NONE)
PASSED=0; TOTAL=0; CODE=not_run
if [ -s "$C" ]; then PASSED=$(jq -r '.passed' "$C"); TOTAL=$(jq -r '.total' "$C"); CODE=$(jq -r '.result' "$C"); fi
JUDGE=$(clean "${JUDGE_OVERALL:-}" not_run); JFAIL=$(clean "${JUDGE_FAILED:-}" "")
JSUM=$(clean "${JUDGE_SUMMARY:-}" ""); ESUM=$(clean "${EXPLANATION_SUMMARY:-}" "")
OVERALL=FAIL; [ "$CODE" = "PASS" ] && [ "$JUDGE" = "PASS" ] && OVERALL=PASS
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

Q="accountIdentifier=${HARNESS_ACCOUNT}&orgIdentifier=${HARNESS_ORG}&projectIdentifier=${HARNESS_PROJECT}"
FS="https://app.harness.io/ng/api/file-store"
# File Store identifiers allow letters, digits and underscore only
SAFE() { printf '%s' "$1" | tr -c 'A-Za-z0-9_' '_'; }

upload() { # $1=identifier  $2=file  $3=mime  $4=METHOD(POST|PUT)
  local url="$FS?$Q"; [ "$4" = "PUT" ] && url="$FS/$1?$Q"
  curl -sS -o /tmp/up.json -w '%{http_code}' --max-time 30 -X "$4" -H "x-api-key: ${HARNESS_API_KEY}" \
    -F "identifier=$1" -F "name=$1.${5:-csv}" -F "type=FILE" -F "parentIdentifier=Root" \
    -F "fileUsage=CONFIG" -F "mimeType=$3" -F "content=@$2" "$url" 2>/dev/null || echo 000
}

# ---------- 1) CSV ledger ----------
LID="agent_eval_$(SAFE "$(printf '%s' "$PIPELINE_ID" | tr '[:upper:]' '[:lower:]')")"
L=/tmp/eval_ledger.csv
code=$(curl -sS -o "$L" -w '%{http_code}' --max-time 30 -H "x-api-key: ${HARNESS_API_KEY}" "$FS/files/$LID/download?$Q" 2>/dev/null || echo 000)
EXISTS=0
if [ "$code" = "200" ] && head -1 "$L" 2>/dev/null | grep -q '^timestamp,'; then EXISTS=1
else echo "timestamp,execution_id,zone,code_passed,code_total,code_result,judge_overall,judge_failed,overall" > "$L"; fi
echo "${NOW},${EXECUTION_ID},${ZONE},${PASSED},${TOTAL},${CODE},${JUDGE},${JFAIL},${OVERALL}" >> "$L"
M=POST; [ "$EXISTS" = "1" ] && M=PUT
up1=$(upload "$LID" "$L" text/csv "$M" csv)

# ---------- 2) per-run detail bundle ----------
B=/tmp/eval_bundle.json
AGENT_OUT=null; PLAN_FILE=/tmp/empty.txt; : > /tmp/empty.txt
if [ "${INCLUDE_AGENT_OUTPUT:-true}" = "true" ]; then AGENT_OUT=$(jfile "$F"); PLAN_FILE=$(rf "$P"); fi
jq -n --arg execution "$EXECUTION_ID" --arg pipeline "$PIPELINE_ID" --arg ts "$NOW" --arg zone "$ZONE" \
  --arg overall "$OVERALL" --arg judge "$JUDGE" --arg judge_failed "$JFAIL" --arg judge_summary "$JSUM" \
  --arg explanation_summary "$ESUM" \
  --argjson code_checks "$(jfile "$C")" --argjson judge_detail "$(jfile "$J")" --argjson agent_output "$AGENT_OUT" \
  --rawfile explanation "$(rf "$X")" --rawfile plan "$PLAN_FILE" \
  '{execution:$execution, pipeline:$pipeline, timestamp:$ts, overall:$overall, zone:$zone,
    code_checks:$code_checks, judge:{overall:$judge, failed:$judge_failed, summary:$judge_summary, detail:$judge_detail},
    explanation:{summary:$explanation_summary, text:$explanation}, agent_output:$agent_output, plan_md:$plan}' > "$B" 2>/tmp/bundle.err \
  || echo "bundle not built: $(head -c 200 /tmp/bundle.err)"
BID="agent_eval_run_$(SAFE "$EXECUTION_ID")"
up2=000; [ -s "$B" ] && up2=$(upload "$BID" "$B" application/json POST json)

ok() { [ "${1:0:1}" = "2" ] && echo saved || echo "NOT saved (HTTP $1)"; }
echo "================ Eval history: $PIPELINE_ID ================"
echo "This run : overall=$OVERALL zone=$ZONE code=$CODE ($PASSED/$TOTAL) judge=$JUDGE $JFAIL"
awk -F, 'NR>1 { r++; if ($9=="PASS") p++ } END { printf "All runs : %d run(s), overall PASS in %d\n", r, p }' "$L"
echo "Ledger   : $LID.csv -> $(ok "$up1")"
echo "Detail   : $BID.json -> $(ok "$up2")"
echo "Last runs:"; tail -n 5 "$L"
exit 0
