"""CI regression gate (runs on every push via .github/workflows/eval.yml).

Small LIVE sweep against OpenRouter: first EVAL_LIVE_N cases (default 5),
temperature 0, response caching on. Keep it capped — a push should cost
pennies. The gate fails the build when the pass rate drops below
harness.PASS_THRESHOLD: that's the point. When you improve your system,
thresholds only move UP, with evidence.
"""
import os
import sys
import pathlib

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

if not os.environ.get("OPENROUTER_API_KEY"):
    pytest.skip("OPENROUTER_API_KEY not set — eval gate needs the repository secret "
                "(Settings → Secrets and variables → Actions).",
                allow_module_level=True)

import harness  # noqa: E402

LIVE_N = int(os.environ.get("EVAL_LIVE_N", "5"))


def test_regression_gate():
    results = harness.run_sweep(limit=LIVE_N)
    rate = sum(r["pass"] for r in results) / len(results)
    failing = [f"{r['id']}: {r['assertion']} / {r['judge']}"
               for r in results if not r["pass"]]
    assert rate >= harness.PASS_THRESHOLD, (
        f"pass rate {rate:.0%} < threshold {harness.PASS_THRESHOLD:.0%}\n"
        + "\n".join(failing))
