# evals/ : Preflight agent evals

REPO-SIDE (commit this whole folder to the repo your pipeline clones, k8s-microservices-app):
  grade_output.py     the code grader (12 checks): exit 1 on failure, writes eval_code.json
  eval_history.sh     saves results to the Harness File Store (CSV ledger + one detail bundle per run)
  run_demo.sh         run the grader locally on saved outputs (no API key)
  fixtures/           MOCK sample outputs (good and bad) + fixtures/judge/<case>/ for judge calibration
  fixtures/real/      put REAL captured outputs here

HARNESS-SIDE (paste into Harness; kept here for version control):
  harness/eval_bot.agent.yaml         the LLM-judge Worker Agent (create in AI > Worker Agents)
  harness/eval_steps.yaml             the 4 steps to paste into k8s_Preflight_Agent_Harshita
  harness/judge_test_pipeline.yaml    calibration pipeline: judge a saved good/bad plan in about a minute

LOCAL TRY-OUT:   bash run_demo.sh

WHERE RESULTS GO
  Step logs                          full PASS/FAIL list, scorecard, judge reasoning
  File Store: agent_eval_<pipeline>.csv         one summary row per run (history)
  File Store: agent_eval_run_<executionId>.json  full detail per run: code checks, judge verdicts,
                                                 explanation, and (optionally) the agent's output.json + plan.md
