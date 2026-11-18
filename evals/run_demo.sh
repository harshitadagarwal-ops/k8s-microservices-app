#!/usr/bin/env bash
# Runs the code grader on saved outputs. Instant, free, no API key.
#   bash run_demo.sh                       all fixtures
#   bash run_demo.sh good_multi_hop 1.36   one fixture (second arg = target version)
cd "$(dirname "$0")"
run() { echo "=============== $1 (current $2 -> target $3) ==============="
        python3 grade_output.py "fixtures/$1.json" --current "$2" --target "$3"; echo "exit code: $?"; echo; }
if [ -n "$1" ]; then run "$1" 1.34 "${2:-1.36}"; exit; fi
run good_single_hop 1.34 1.35
run good_multi_hop 1.34 1.36
run bad_skipped_hop 1.34 1.36
run bad_truncated 1.34 1.35
run bad_green_with_critical 1.34 1.36
