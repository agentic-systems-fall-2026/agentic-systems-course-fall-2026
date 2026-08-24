#!/usr/bin/env python3
"""Build Challenge 2 starter — a task built to fail from context overload.

Run from the repo root:  python3 bc2-context/overload_task.py

This script answers a compliance question that depends on exactly THREE of the
thirty policy documents below — but it naively stuffs ALL thirty into a single
context. Depending on model and day you'll see drift, ignored instructions,
made-up policy numbers, or a hard overflow error. That failure is the point.

YOUR JOB (see README.md): reproduce and document the failure, then fix it with
techniques from the pre-read — compaction, just-in-time retrieval, note-taking,
system-prompt altitude. Keep this file as the "before"; build your fix in
fixed_task.py so the two are comparable.
"""
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from common.llm import chat, load_prompt, STATS

QUESTION = ("A student employee wants to run a long-lived agent on a lab "
            "machine over the weekend, unattended, with access to a shared "
            "drive. Under our policies, what approvals do they need, what "
            "logging is required, and what is the maximum unattended runtime? "
            "Cite the policy numbers you used.")

# The three documents that actually matter:
RELEVANT = {
    7:  "POLICY AS-7 (Unattended Automation): agents running unattended for "
        "more than 4 hours require written supervisor approval AND a named "
        "on-call contact. Maximum unattended runtime is 72 hours.",
    18: "POLICY AS-18 (Audit Logging): any automated system touching shared "
        "storage must write an append-only action log with timestamps, and "
        "logs must be retained for 90 days.",
    24: "POLICY AS-24 (Shared Drive Access): automation accessing shared "
        "drives requires read-only credentials by default; write access "
        "needs a data-owner sign-off recorded in the request ticket.",
}

# Traps: superseded/expired versions with DIFFERENT numbers, buried in the
# haystack. A context-overloaded model tends to cite one of these instead.
TRAPS = {
    12: "POLICY AS-12 (Automation Pilot Program — EXPIRED 2024, retained for "
        "records only): pilot agents were capped at 12 hours unattended "
        "runtime with lab-manager approval; logs kept 30 days.",
    27: "POLICY AS-27 (Legacy Unattended Automation — RESCINDED, superseded "
        "by AS-7): unattended runtime capped at 24 hours; verbal supervisor "
        "approval sufficient; no on-call contact required.",
}

random.seed(4243)  # same haystack for everyone
FILLER_TOPICS = ["visitor parking", "printer quotas", "meeting-room booking",
                 "coffee fund", "poster printing", "bicycle storage",
                 "holiday scheduling", "office plants", "recycling",
                 "keyboard replacement", "software licences", "travel forms"]


def make_docs():
    docs = []
    for i in range(1, 31):
        if i in RELEVANT:
            body = RELEVANT[i]
        elif i in TRAPS:
            body = TRAPS[i]
        else:
            t = random.choice(FILLER_TOPICS)
            body = (f"POLICY AS-{i} ({t.title()}): " +
                    " ".join(f"Provision {j}: requests regarding {t} must be "
                             f"submitted via the AS-{i} form no later than "
                             f"{random.randint(2, 14)} business days in advance, "
                             f"subject to review by the {t} committee."
                             for j in range(1, 26)))
        docs.append(f"=== DOCUMENT {i} ===\n{body}")
    return docs


def main():
    docs = make_docs()
    blob = "\n\n".join(docs)
    print(f"Stuffing {len(docs)} documents (~{len(blob):,} chars) into one request…")
    answer = chat(
        [{"role": "system", "content": load_prompt("bc2-analyst.txt")},
         {"role": "user", "content": blob + "\n\nQUESTION: " + QUESTION}],
        max_tokens=500)
    print("\n" + answer)
    print(f"\nSTATS: {STATS}")
    print("\nGround truth: AS-7 (written approval + on-call contact, 72h max), "
          "AS-18 (append-only logs, 90-day retention), AS-24 (read-only creds / "
          "data-owner sign-off). Did it cite exactly these, with correct "
          "details — or did it fall for the expired AS-12 (12h) or rescinded "
          "AS-27 (24h, verbal approval)?")


if __name__ == "__main__":
    main()
