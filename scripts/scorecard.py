#!/usr/bin/env python3
# scorecard.py -- one command, one verdict: run every in-repo gate and publish a
# machine-readable trust artifact.
#
# Why this exists: the repo's gates were three commands a human had to run and
# read. That is fine for the maintainer and useless for everyone else. A scorecard
# turns "trust me" into "run this and read the JSON" -- the quantified-trust shape
# that skill marketplaces are moving toward.
#
# Scope, stated honestly: it runs ONLY the gates that live in this repo
# (verify_examples.R / verify_prompts.R / check_consistency.py). The birth
# checklist (luban's check-skill-repo.sh) lives outside the repo and is NOT run
# here. The 47-case snippet census is a workspace tool, also not run here.
#
# Zero dependencies (stdlib only), like its three siblings.
#
# Usage (any CWD):
#   python scripts/scorecard.py            # run gates, print the card + JSON
#   python scripts/scorecard.py --write    # also refresh verification.json
# Exit code: 0 = every gate green; 1 = at least one red.

import datetime
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = os.path.join(ROOT, "verification.json")
# Rscript is assumed to be on PATH (as the README documents). Set RSCRIPT to
# override -- handy on machines where R lives outside PATH, and in CI.
RSCRIPT = os.environ.get("RSCRIPT", "Rscript")


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def skill_version():
    """The newest released version, read from CHANGELOG (single source of truth)."""
    m = re.search(r"^## \[(\d+\.\d+\.\d+)\]", read("CHANGELOG.md"), re.M)
    return m.group(1) if m else None


def run(cmd):
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True)
    return r.returncode, r.stdout.decode("utf-8", errors="replace")


def gate_examples():
    rc, out = run([RSCRIPT, "--vanilla", "scripts/verify_examples.R"])
    m = re.search(r"Summary: (\d+)/(\d+) PASS", out)
    got, total = (int(m.group(1)), int(m.group(2))) if m else (0, 0)
    return {"name": "paradigm cases", "command": "Rscript --vanilla scripts/verify_examples.R",
            "passed": got, "total": total, "ok": rc == 0 and got == total and total > 0}


def gate_prompts():
    rc, out = run([RSCRIPT, "--vanilla", "scripts/verify_prompts.R"])
    m = re.search(r"Summary: (\d+) check\(s\), (\d+) failure", out)
    total, bad = (int(m.group(1)), int(m.group(2))) if m else (0, 1)
    return {"name": "prompt tests", "command": "Rscript --vanilla scripts/verify_prompts.R",
            "passed": total - bad, "total": total, "ok": rc == 0 and bad == 0 and total > 0}


def gate_consistency():
    rc, out = run([sys.executable, "scripts/check_consistency.py"])
    m = re.search(r"Summary: (\d+) check\(s\), (\d+) failure", out)
    total, bad = (int(m.group(1)), int(m.group(2))) if m else (0, 1)
    return {"name": "doc-vs-reality", "command": "python scripts/check_consistency.py",
            "passed": total - bad, "total": total, "ok": rc == 0 and bad == 0 and total > 0}


def gate_snippets():
    """The full census: every ```r block in the docs, as 47 executable cases."""
    rc, out = run([RSCRIPT, "--vanilla", "scripts/verify_snippets.R"])
    m = re.search(r"Summary: (\d+)/(\d+) PASS", out)
    got, total = (int(m.group(1)), int(m.group(2))) if m else (0, 0)
    return {"name": "snippet census", "command": "Rscript --vanilla scripts/verify_snippets.R",
            "passed": got, "total": total, "ok": rc == 0 and got == total and total > 0}


def main():
    gates = [gate_examples(), gate_prompts(), gate_snippets(), gate_consistency()]
    green = sum(1 for g in gates if g["ok"])
    verdict = "PASS" if green == len(gates) else "FAIL"
    card = {
        "skill": "data-wrangling",
        "version": skill_version(),
        "generated_at": datetime.datetime.now(datetime.timezone.utc)
                        .replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "verdict": verdict,
        "gates_passed": green,
        "gates_total": len(gates),
        # Explicit counts so a marketplace (or the repo's own checker) can consume
        # them without parsing prose.
        "regression_cases": gates[0]["passed"],
        "prompt_checks": gates[1]["passed"],
        "snippet_cases": gates[2]["passed"],
        "consistency_checks": gates[3]["passed"],
        "gates": gates,
        "scope_note": ("In-repo gates only: the external birth checklist is not "
                       "run here."),
    }

    print("\n  data-wrangling · verification scorecard\n")
    for g in gates:
        print("  {:<18} {:>3}/{:<3}  {}".format(g["name"], g["passed"], g["total"],
                                                "PASS" if g["ok"] else "FAIL"))
    print("\n  verdict: {} ({}/{} gates green)   version: {}\n".format(
        verdict, green, len(gates), card["version"]))

    if "--write" in sys.argv:
        with open(JSON_PATH, "w", encoding="utf-8", newline="\n") as f:
            json.dump(card, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print("  wrote {}".format(os.path.relpath(JSON_PATH, ROOT)))
    print(json.dumps({k: v for k, v in card.items() if k != "gates"},
                     ensure_ascii=False, indent=2))
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
