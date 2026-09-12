#!/usr/bin/env python3
# check_consistency.py -- the closing step for this skill's maintenance loop.
#
# Red-team rounds showed every gap was a sync drift: doc claims (counts,
# references) lagging behind the actual files after manual edits. This script
# mechanizes that closing step: every declared number must equal the actual
# count, every referenced file must exist, no stale tokens may remain.
#
# Python on purpose: unicode-safe under any locale (the R sibling scripts hit
# parser/locale landmines documented in their headers). Run from anywhere:
#   python scripts/check_consistency.py
# Exit code: 0 = consistent; 1 = drift found.

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

failures = 0
total = 0


def check(name, cond, detail=""):
    global failures, total
    total += 1
    ok = bool(cond)
    if not ok:
        failures += 1
    line = "[{}] {}{}".format("PASS" if ok else "FAIL", name,
                               " -- " + detail if detail else "")
    print(line)


def read_doc(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()


# 1. actual counts from the two regression scripts ---------------------------
with open(os.path.join(ROOT, "scripts/verify_examples.R"), encoding="utf-8") as f:
    ex = f.read()
with open(os.path.join(ROOT, "scripts/verify_prompts.R"), encoding="utf-8") as f:
    pr = f.read()
n_cases = len(re.findall(r"^\s*run_case\(", ex, re.M))
n_checks = len(re.findall(r'check\("', pr))

# 2. claimed counts in docs (CHANGELOG excluded: historical record) -----------
docs = ["SKILL.md", "references/paradigms.md", "README.md"]
for d in docs:
    dt = read_doc(d)
    cl = re.findall(r"[（(](\d+) 例[）)]", dt)          # "(N li)" paren claims
    if d == "README.md":
        # README states counts in table/tree wording, not parens -- optional
        check("{}: paren claims (if any) == {}".format(d, n_cases),
              len(cl) == 0 or all(int(x) == n_cases for x in cl),
              "claimed: " + ",".join(sorted({x for x in cl if int(x) != n_cases}))
              if any(int(x) != n_cases for x in cl) else "")
    else:
        check("{}: '(N 例)' claims present and == {}".format(d, n_cases),
              len(cl) > 0 and all(int(x) == n_cases for x in cl),
              "no claim found" if len(cl) == 0 else
              ("claimed: " + ",".join(sorted({x for x in cl if int(x) != n_cases}))
               if any(int(x) != n_cases for x in cl) else ""))
    cp = re.findall(r"(\d+) 题", dt)                     # prompt count = 3
    check("{}: '(N 题)' claims (if any) == 3".format(d),
          len(cp) == 0 or all(int(x) == 3 for x in cp),
          "claimed: " + ",".join(sorted({x for x in cp if int(x) != 3}))
          if any(int(x) != 3 for x in cp) else "")
    ck = re.findall(r"(\d+) 检查", dt)                   # check count
    check("{}: '(N 检查)' claims (if any) == {}".format(d, n_checks),
          len(ck) == 0 or all(int(x) == n_checks for x in ck),
          "claimed: " + ",".join(sorted({x for x in ck if int(x) != n_checks}))
          if any(int(x) != n_checks for x in ck) else "")
    cli = re.findall(r"(?<!第 )(?<!\d)(\d+) 例", dt)             # any "N 例" wording
    check("{}: '(N 例)' wording (if any) == {}".format(d, n_cases),
          len(cli) == 0 or all(int(x) == n_cases for x in cli),
          "claimed: " + ",".join(sorted({x for x in cli if int(x) != n_cases}))
          if any(int(x) != n_cases for x in cli) else "")

# 3. quick-reference section count vs README claim ----------------------------
sk = read_doc("SKILL.md")
n_qr = len(re.findall(r"^### 6\.\d+ ", sk, re.M))
cl_qr = re.findall(r"(\d+) 段最短范型速查", read_doc("README.md"))
check("README: quickref claim present and == {}".format(n_qr),
      len(cl_qr) > 0 and all(int(x) == n_qr for x in cl_qr),
      "no claim found" if len(cl_qr) == 0 else
      ("claimed: " + ",".join(sorted({x for x in cl_qr if int(x) != n_qr}))
       if any(int(x) != n_qr for x in cl_qr) else ""))

# 4. anti-pattern table rows vs README claim ----------------------------------
sk_lines = sk.split("\n")
i7 = next(i for i, l in enumerate(sk_lines) if l.startswith("## 7."))
i8 = next(i for i, l in enumerate(sk_lines) if l.startswith("## 8."))
tbl = sk_lines[i7 + 1:i8]
n_ap = sum(1 for l in tbl if l.startswith("| ")) - 1   # minus header (the |--- separator does not start with "| ")
cl_ap = re.findall(r"反模式黑名单 (\d+) 条", read_doc("README.md"))
check("README: anti-pattern claim present and == {}".format(n_ap),
      len(cl_ap) > 0 and all(int(x) == n_ap for x in cl_ap),
      "no claim found" if len(cl_ap) == 0 else
      ("claimed: " + ",".join(sorted({x for x in cl_ap if int(x) != n_ap}))
       if any(int(x) != n_ap for x in cl_ap) else ""))

# 5. referenced files exist ----------------------------------------------------
for f in ["references/paradigms.md", "assets/data-thinking-2.0.png",
          "scripts/verify_examples.R", "scripts/verify_prompts.R",
          "scripts/check_consistency.py",
          "test-prompts.json", "LICENSE", "CHANGELOG.md", "README.md",
          "SKILL.md"]:
    check("file exists: " + f, os.path.exists(os.path.join(ROOT, f)))

# 6. no stale tokens (superseded / outdated claims) ----------------------------
stale = ["（9 例）", "9/9 PASS", "11 段最短范型速查",
         "9 例范式回归", "9 范式例"]
for d in docs:
    dt = read_doc(d)
    hit = [p for p in stale if p in dt]
    check("{}: no stale tokens".format(d), len(hit) == 0,
          "found: " + ", ".join(hit) if hit else "")
check("SKILL.md: no bare separate( (superseded)",
      re.search(r"(?<!旧 )separate\(", sk) is None)

# summary -----------------------------------------------------------------------
print("\nSummary: {} check(s), {} failure(s)".format(total, failures))
sys.exit(1 if failures else 0)
