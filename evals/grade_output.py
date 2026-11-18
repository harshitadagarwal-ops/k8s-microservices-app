#!/usr/bin/env python3
"""Grades the Preflight agent's output.json with plain code checks.
No API key and no pip installs needed (standard library only).

Usage:
  python evals/grade_output.py /harness/preflight/output.json --current 1.34 --target 1.36

Exit code 0 = pass, 1 = fail (this is what turns the Harness step red).

Check types:
  HARD = must always hold. Any HARD failure fails the run.
  SOFT = quality signals. They count toward the pass rate (threshold below).
"""
import argparse
import json
import re
import sys

ZONES = {"GREEN", "AMBER", "RED"}


def minor(v):
    m = re.match(r"^v?1\.(\d+)", str(v or ""))
    return int(m.group(1)) if m else None


def num(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool)


def findings(o):
    return o.get("findings") or o.get("issues") or []


# ---------------------------------------------------------------- HARD checks
def valid_output(o, ctx):
    s = o.get("score") or {}
    ok = (s.get("zone") in ZONES and num(s.get("initial")) and num(s.get("projected"))
          and 0 <= s["initial"] <= 100 and 0 <= s["projected"] <= 100)
    return ok, f"zone={s.get('zone')} initial={s.get('initial')} projected={s.get('projected')}"


def scan_completed(o, ctx):
    # The pipeline itself treats score 0 as "the cluster could not be scanned at all".
    v = (o.get("score") or {}).get("initial")
    return num(v) and v > 0, f"initial score = {v}"


def current_version_matches(o, ctx):
    return minor(o.get("current_version")) == minor(ctx.current), \
        f"agent says {o.get('current_version')}, pipeline input is {ctx.current}"


def hops_complete_and_ordered(o, ctx):
    cur, tgt = minor(ctx.current), minor(ctx.target)
    want = list(range(cur + 1, tgt + 1))
    got = [minor(h.get("to")) for h in (o.get("hops") or [])]
    return got == want, f"expected hops to {['1.%d' % m for m in want]}, got {[('1.%d' % m) if m else None for m in got]}"


def projected_not_below_initial(o, ctx):
    s = o.get("score") or {}
    ok = num(s.get("initial")) and num(s.get("projected")) and s["projected"] >= s["initial"]
    return ok, f"initial={s.get('initial')} projected={s.get('projected')}"


def green_means_clean(o, ctx):
    zone = (o.get("score") or {}).get("zone")
    if zone != "GREEN":
        return True, f"zone is {zone}, not applicable"
    crit = [f for f in findings(o) if str(f.get("severity", "")).upper() == "CRITICAL"]
    blockers = o.get("top_blockers") or []
    return not crit and not blockers, f"{len(crit)} critical finding(s), {len(blockers)} blocker(s) while zone is GREEN"


# ---------------------------------------------------------------- SOFT checks
def support_info_present(o, ctx):
    s = o.get("support") or {}
    ok = bool((s.get("current") or {}).get("status")) and bool(s.get("urgency"))
    return ok, "support.current.status and support.urgency present" if ok else "support info missing"


def prs_are_valid_links(o, ctx):
    bad = [p.get("url") for p in (o.get("prs") or []) if not re.search(r"/pull/\d+$", str(p.get("url") or ""))]
    return not bad, f"bad PR links: {bad}" if bad else "all PR links look valid"


def flagged_hops_explain_why(o, ctx):
    bad = [h.get("to") for h in (o.get("hops") or [])
           if str(h.get("status", "")).upper() == "FLAGGED"
           and not (h.get("removed_apis") or h.get("removed") or h.get("notes") or h.get("note") or h.get("reason"))]
    return not bad, f"flagged hops with no explanation: {bad}" if bad else "every flagged hop has a reason"


def findings_have_evidence(o, ctx):
    bad = [f.get("resource") or f.get("name") or "?" for f in findings(o)
           if not (f.get("evidence") or f.get("message") or f.get("detail") or f.get("description"))]
    return not bad, f"findings without evidence: {bad}" if bad else "all findings cite evidence"


def verdict_explains_itself(o, ctx):
    zone = (o.get("score") or {}).get("zone")
    if zone == "GREEN":
        return True, "GREEN, no blockers needed"
    ok = bool(o.get("top_blockers"))
    return ok, f"zone {zone} with {len(o.get('top_blockers') or [])} blocker(s) listed"


def fixes_have_prs(o, ctx):
    files = [f for p in (o.get("pr_patches") or []) for f in (p.get("files") or [])]
    ok = (not files) or bool(o.get("prs"))
    return ok, f"{len(files)} patched file(s), {len(o.get('prs') or [])} PR(s)"


CHECKS = [
    ("HARD", valid_output), ("HARD", scan_completed), ("HARD", current_version_matches),
    ("HARD", hops_complete_and_ordered), ("HARD", projected_not_below_initial), ("HARD", green_means_clean),
    ("SOFT", support_info_present), ("SOFT", prs_are_valid_links), ("SOFT", flagged_hops_explain_why),
    ("SOFT", findings_have_evidence), ("SOFT", verdict_explains_itself), ("SOFT", fixes_have_prs),
]


def write_summary(path, results, hard_failed, rate, result):
    if not path:
        return
    with open(path, "w") as f:
        json.dump({"result": result, "passed": sum(r["ok"] for r in results), "total": len(results),
                   "rate": round(rate, 4), "hard_failed": hard_failed, "checks": results}, f, indent=2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--current", required=True)
    ap.add_argument("--target", required=True)
    ap.add_argument("--threshold", type=float, default=0.9, help="min overall pass rate")
    ap.add_argument("--json-out", default="", help="write a machine-readable summary here")
    ctx = ap.parse_args()

    try:
        with open(ctx.path) as f:
            out = json.load(f)
    except Exception as e:
        print(f"FAIL  [HARD] valid_output: cannot read {ctx.path}: {e}")
        print("\nRESULT: FAIL")
        write_summary(ctx.json_out, [{"name": "valid_output", "severity": "HARD", "ok": False, "detail": str(e)}],
                      True, 0.0, "FAIL")
        return 1

    results, hard_failed = [], False
    for sev, fn in CHECKS:
        try:
            ok, detail = fn(out, ctx)
        except Exception as e:  # a malformed output should fail a check, not crash the grader
            ok, detail = False, f"check crashed on malformed output: {e}"
        ok = bool(ok)
        results.append({"name": fn.__name__, "severity": sev, "ok": ok, "detail": detail})
        hard_failed |= (sev == "HARD" and not ok)
        print(f"{'PASS' if ok else 'FAIL'}  [{sev}] {fn.__name__}" + ("" if ok else f"\n        {detail}"))

    passed = sum(r["ok"] for r in results)
    rate = passed / len(CHECKS)
    result = "FAIL" if (hard_failed or rate < ctx.threshold) else "PASS"
    print(f"\nChecks passed: {passed}/{len(CHECKS)} = {rate:.0%} (need {ctx.threshold:.0%}, and no HARD failures)")
    print(f"RESULT: {result}")
    write_summary(ctx.json_out, results, hard_failed, rate, result)
    return 0 if result == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
