#!/usr/bin/env python3
# check_consistency.py -- the closing step for this skill's maintenance loop.
#
# Red-team rounds showed every gap was a sync drift: doc claims (counts,
# references) lagging behind the actual files after manual edits. This script
# mechanizes that closing step: every declared number must equal the actual
# count, every referenced file must exist, no stale tokens may remain.
#
# The scope grew after the tidy-data -> data-wrangling rename proved that a
# rename is exactly the class of edit this script used to miss (it only counted
# numbers, so a leftover old name passed silently). Now it also guards:
#   - identity: directory name == frontmatter name == README titles
#   - cross-skill contracts: related-skills resolve and point back
#   - routing: no sibling claims our trigger phrases without delegating to us
#   - narrative artifacts (examples/) and the declared check count itself
#   - external claims: identity-bearing URLs and the README regression badge
#     (both rotted while nothing read them: a skills.sh path kept the old slug
#     and 404'd, and the badge still said 28/28 after the checker grew to 57)
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


def badge_counts(text):
    """[(n, n), ...] from the shields.io regression badge, or None if absent.

    The badge encodes its three counts as '14%2F14%20%C2%B7%207%2F7%20...', so
    decode %2F to '/' and keep every 'N/N' piece.
    """
    m = re.search(r"regression-([^\s)\"'>]+)", text)
    if not m:
        return None
    out = []
    for part in m.group(1).replace("%2F", "/").split("%20"):
        mm = re.match(r"(\d+)/(\d+)$", part)
        if mm:
            out.append((int(mm.group(1)), int(mm.group(2))))
    return out


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
          "assets/decision-tree.png", "assets/decision-tree.svg",
          "assets/demo.gif",
          "scripts/verify_examples.R", "scripts/verify_prompts.R",
          "scripts/check_consistency.py",
          "test-prompts.json", "LICENSE", "CHANGELOG.md", "README.md",
          "README.en.md", "MAINTAINING.md", "SKILL.md", "VERIFICATION.md",
          "examples/README.md",
          "examples/case-01-wide-to-long.md",
          "examples/case-02-grouped-mom-and-complete-groups.md",
          "examples/case-03-perpetual-inventory.md"]:
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

# 7. identity: directory name == frontmatter name == README titles ------------
# A rename must be all-or-nothing: the skill id IS the directory name, so any
# mismatch silently forks the identity across runtimes.
PARENT = os.path.dirname(ROOT)
DIRNAME = os.path.basename(ROOT)
fm = re.search(r"\A---\s*\n(.*?)\n---\s*\n", sk, re.S)
front = fm.group(1) if fm else ""
name_m = re.search(r"^name:\s*(\S+)\s*$", front, re.M)
skill_name = name_m.group(1) if name_m else ""
check("frontmatter name == directory name", skill_name == DIRNAME,
      "name={!r} dir={!r}".format(skill_name, DIRNAME))
for rd in ["README.md", "README.en.md"]:
    h1 = re.search(r"^#\s+(\S+)", read_doc(rd), re.M)
    check("{} H1 carries the skill id".format(rd),
          bool(h1) and h1.group(1) == skill_name,
          "H1={!r} name={!r}".format(h1.group(1) if h1 else None, skill_name))

# 8. cross-skill contracts: related-skills resolve, peers point back ----------
rel_block = re.search(r"^related-skills:\s*\n((?:\s+-\s+\S+\s*\n)+)", front, re.M)
peers = re.findall(r"-\s*(\S+)", rel_block.group(1)) if rel_block else []
check("related-skills declares at least one peer", len(peers) > 0)
for peer in peers:
    check("related-skill exists: " + peer,
          os.path.isdir(os.path.join(PARENT, peer)))
    p = os.path.join(PARENT, peer, "SKILL.md")
    if os.path.isfile(p):
        with open(p, encoding="utf-8") as f:
            peer_text = f.read()
        check("peer {} links back to {}".format(peer, skill_name),
              skill_name in peer_text)

# 9. the legacy skill name must not survive in live docs ----------------------
# (CHANGELOG is exempt: it is the one place the old name must stay, to explain
# the rename. Everything a reader would follow today must use the new name.)
LEGACY_NAME = "tidy-data"
for d in ["SKILL.md", "references/paradigms.md", "README.md", "README.en.md",
          "scripts/verify_examples.R", "scripts/verify_prompts.R",
          "MAINTAINING.md", "examples/README.md"]:
    check("{}: no legacy skill name".format(d),
          LEGACY_NAME not in read_doc(d))

# 10. routing signals ---------------------------------------------------------
# Offline we cannot measure "did the agent pick this skill", but we can measure
# the signals selection depends on: declared triggers, a stated boundary, and
# whether a co-resident skill claims our phrases without delegating to us.
check("description declares Triggers:", "Triggers:" in front)
check("description declares a negative boundary", "不适用" in front)
tr_m = re.search(r"Triggers:\s*(.+)", front)
n_trigger = len([t for t in re.split(r"[/、]", tr_m.group(1))
                 if t.strip(" .。")]) if tr_m else 0
check("triggers: at least 6 vocabulary entries", n_trigger >= 6,
      "found {}".format(n_trigger))

DISTINCTIVE = ["数据思维", "tidyverse 怎么写", "宽表转长表", "不要用 for 循环"]
# Accepted overlaps: restating a phrase while NOT delegating is the anti-pattern
# we fail on. This dict is empty on purpose: the one overlap we found
# (learning-method restating 数据思维 without pointing here) was fixed by making
# it delegate, so it must not stay masked by a whitelist entry. Keep it empty --
# if a future overlap is genuinely accepted, add it WITH a written reason.
KNOWN_OVERLAPS = {}
roamers = []
for sib in sorted(os.listdir(PARENT)):
    if sib == DIRNAME or not os.path.isdir(os.path.join(PARENT, sib)):
        continue
    p = os.path.join(PARENT, sib, "SKILL.md")
    if not os.path.isfile(p):
        continue
    with open(p, encoding="utf-8") as f:
        sib_text = f.read()
    hits = [w for w in DISTINCTIVE if w in sib_text]
    if hits and skill_name not in sib_text and sib not in KNOWN_OVERLAPS:
        roamers.append("{}: {}".format(sib, ",".join(hits)))
check("no sibling claims our triggers without delegating", not roamers,
      "; ".join(roamers))

# 11. narrative artifacts (examples/) ----------------------------------------
N_EXAMPLES = 3
cl_ex = re.findall(r"(\d+) 个真实案例", read_doc("README.md"))
check("README: '(N) 个真实案例' claim present and == {}".format(N_EXAMPLES),
      len(cl_ex) > 0 and all(int(x) == N_EXAMPLES for x in cl_ex),
      "no claim found" if len(cl_ex) == 0 else
      ("claimed: " + ",".join(sorted({x for x in cl_ex if int(x) != N_EXAMPLES}))
       if any(int(x) != N_EXAMPLES for x in cl_ex) else ""))
n_case_files = len([f for f in os.listdir(os.path.join(ROOT, "examples"))
                    if re.match(r"case-\d\d-.*\.md$", f)])
check("examples/ holds {} case files".format(N_EXAMPLES),
      n_case_files == N_EXAMPLES, "found {}".format(n_case_files))

# 13. written-in external claims ----------------------------------------------
# A claim no script reads is a claim that rots. Two of them did, in the same
# week: the distribution links (a skills.sh path kept the pre-rename slug and
# 404'd) and the README regression badge (still 28/28 long after the checker
# grew to 57). Bind both to the files that actually know the truth.
SELF_COUNT_DOCS = ["README.md", "SKILL.md", "README.en.md"]

# (a) Links that carry our identity must carry the CURRENT slug. Peers' links are
#     left alone -- only URLs naming us (zhjx19) are policed, which is exactly the
#     class that broke.
all_urls = []
for d in ["SKILL.md", "README.md", "README.en.md", "MAINTAINING.md"]:
    all_urls += re.findall(r"""https?://[^\s)\]"'>]+""", read_doc(d))
bad_urls = sorted({u for u in all_urls
                   if ("zhjx19" in u and "data-wrangling" not in u)
                   or LEGACY_NAME in u})
check("external links: identity-bearing URLs carry the current slug",
      not bad_urls, "offending: " + ", ".join(bad_urls))

# (b) The badge hardcodes three counts: the two measured above plus the
#     self-count this file is about to require. (+1 = this check itself.)
expected_self = total + 1 + len(SELF_COUNT_DOCS)
badge_bad = []
for d in ["README.md", "README.en.md"]:
    nums = badge_counts(read_doc(d))
    want = [(n_cases, n_cases), (n_checks, n_checks),
            (expected_self, expected_self)]
    if nums is None:
        badge_bad.append("{}: no regression badge".format(d))
    elif nums != want:
        badge_bad.append("{}: {} != {}".format(d, nums, want))
check("external claims: regression badge counts match the scripts",
      not badge_bad, "; ".join(badge_bad))

# 12. the declared check count itself ----------------------------------------
# SELF_COUNT_DOCS is defined in section 13 (the badge check needs it first).
# The self-count checks below are themselves counted, so the number the docs
# must declare is known in advance: total so far + one per doc examined.
# Deriving it from the same list keeps the counter and the claim in lockstep.
REPORTED = total + len(SELF_COUNT_DOCS)
for d in SELF_COUNT_DOCS:
    dt = read_doc(d)
    claimed = re.findall(r"(\d+)\s*(?:项|doc-vs-reality)", dt)
    check("{}: '(N) 项' self-count == {}".format(d, REPORTED),
          len(claimed) > 0 and all(int(x) == REPORTED for x in claimed),
          "no claim found" if len(claimed) == 0 else
          ("claimed: " + ",".join(sorted({x for x in claimed if int(x) != REPORTED}))
           if any(int(x) != REPORTED for x in claimed) else ""))
if total != REPORTED:  # arithmetic guard; does not call check() on purpose
    print("[FAIL] self-count bookkeeping -- total={} REPORTED={}".format(
        total, REPORTED))
    failures += 1

# summary -----------------------------------------------------------------------
print("\nSummary: {} check(s), {} failure(s)".format(total, failures))
sys.exit(1 if failures else 0)
