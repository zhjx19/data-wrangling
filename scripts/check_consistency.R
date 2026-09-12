#!/usr/bin/env Rscript
# check_consistency.R -- the closing step for this skill's maintenance loop.
#
# Red-team rounds showed every gap was a sync drift: doc claims (counts,
# references) lagging behind the actual files after manual edits. This script
# mechanizes that closing step: every declared number must equal the actual
# count, every referenced file must exist, no stale tokens may remain.
#
# 100% ASCII source. Chinese fragments in the docs are matched at BYTE level
# (UTF-8 sequences as \xNN PCRE patterns with useBytes=TRUE), so this runs
# under any locale. Run from anywhere:
#   Rscript --vanilla scripts/check_consistency.R
# Exit code: 0 = consistent; 1 = drift found.

failures = 0L
total    = 0L
check = function(name, cond, detail = "") {
  total    <<- total + 1L
  ok       = isTRUE(cond)
  if (!ok) failures <<- failures + 1L
  cat(sprintf("[%s] %s%s\n", if (ok) "PASS" else "FAIL", name,
              if (nzchar(detail)) paste0(" -- ", detail) else ""))
  invisible(ok)
}
root = normalizePath(dirname(dirname(commandArgs(trailingOnly = FALSE)[
  grep("^--file=", commandArgs(trailingOnly = FALSE))])))
# readr::read_file keeps the raw UTF-8 bytes (readLines would transcode to the
# native GBK codepage under a broken locale, breaking byte-level patterns).
read_doc = \(p) readr::read_file(file.path(root, p))
# byte-level claim extractor: returns integer captures for a UTF-8 byte pattern
claim_b = \(doc_text, byte_pat) {
  m = gregexpr(byte_pat, doc_text, perl = TRUE, useBytes = TRUE)[[1]]
  if (m[1] == -1) return(integer(0))
  caps = regmatches(doc_text, gregexpr(byte_pat, doc_text,
                                       perl = TRUE, useBytes = TRUE))[[1]]
  v = suppressWarnings(as.integer(caps[nzchar(caps)]))
  v[!is.na(v)]
}

# Chinese fragments built from UTF-8 bytes at runtime (locale-proof: the
# source stays ASCII and the pattern bytes match the doc bytes exactly)
LI   = rawToChar(as.raw(c(0xE4, 0xBE, 0x8B)))                       # li
TI   = rawToChar(as.raw(c(0xE9, 0xA2, 0x98)))                       # ti
JIAN = rawToChar(as.raw(c(0xE6, 0xA3, 0x80, 0xE6, 0x9F, 0xA5)))     # check
DUAN = rawToChar(as.raw(c(0xE6, 0xAE, 0xB5, 0xE6, 0x9C, 0x80, 0xE7,
                          0x9F, 0xAD, 0xE8, 0x8C, 0x83, 0xE5, 0x9E,
                          0x8B, 0xE9, 0x80, 0x9F, 0xE6, 0x9F, 0xA5)))  # quickref
FAN  = rawToChar(as.raw(c(0xE5, 0x8F, 0x8D, 0xE6, 0xA8, 0xA1, 0xE5,
                          0xBC, 0x8F, 0xE9, 0xBB, 0x91, 0xE5, 0x90,
                          0x8D, 0xE5, 0x8D, 0x95)))                  # anti-pattern
TIAO = rawToChar(as.raw(c(0xE6, 0x9D, 0xA1)))                       # counter
LP   = rawToChar(as.raw(c(0xEF, 0xBC, 0x88)))                       # (
RP   = rawToChar(as.raw(c(0xEF, 0xBC, 0x89)))                       # )
DI   = rawToChar(as.raw(c(0xE7, 0xAC, 0xAC)))   # "the Nth case" ref prefix -- excluded

## 1. actual counts from the two regression scripts -------------------------
ex_lines = readLines(file.path(root, "scripts/verify_examples.R"), warn = FALSE)
pr_lines = readLines(file.path(root, "scripts/verify_prompts.R"), warn = FALSE)
n_cases  = sum(grepl("^\\s*run_case\\(", ex_lines))
n_checks = sum(grepl("check\\(\"", pr_lines))

## 2. claims in docs (CHANGELOG excluded: historical record) -----------------
docs = c("SKILL.md", "references/paradigms.md", "README.md")
for (d in docs) {
  dt = read_doc(d)
  # "(N li)" paren claims -- must exist in SKILL.md and paradigms.md
  cl = claim_b(dt, paste0(LP, "([0-9]+) ", LI, RP))
  if (d %in% c("SKILL.md", "references/paradigms.md")) {
    check(paste0(d, ": '(N li)' paren claims present and == ", n_cases),
          length(cl) > 0 && all(cl == n_cases),
          if (length(cl) == 0) "no claim found" else
            if (!all(cl == n_cases))
              paste("claimed:", paste(unique(cl[cl != n_cases]), collapse = ",")) else "")
  } else {
    check(paste0(d, ": paren claims (if any) == ", n_cases),
          length(cl) == 0 || all(cl == n_cases),
          if (length(cl) && !all(cl == n_cases))
            paste("claimed:", paste(unique(cl[cl != n_cases]), collapse = ",")) else "")
  }
  # "N li" generic wording (tree lines / tables) must equal actual count
  cli = claim_b(dt, paste0("([0-9]+) ", LI))
  cli = setdiff(cli, cl)                     # paren claims already counted above
  check(paste0(d, ": 'N li' wording (if any) == ", n_cases),
        length(cli) == 0 || all(cli == n_cases),
        if (length(cli) && !all(cli == n_cases))
          paste("claimed:", paste(unique(cli[cli != n_cases]), collapse = ",")) else "")
  # "N ti" claims (prompt count = 3)
  cp = claim_b(dt, paste0("([0-9]+) ", TI))
  cp = unique(cp[cp > 0 & cp < 100])
  check(paste0(d, ": 'N ti' claims (if any) == 3"),
        length(cp) == 0 || all(cp == 3),
        if (length(cp) && !all(cp == 3))
          paste("claimed:", paste(unique(cp[cp != 3]), collapse = ",")) else "")
  # "N jian-cha" claims (check count)
  ck = claim_b(dt, paste0("([0-9]+) ", JIAN))
  ck = unique(ck[ck > 0 & ck < 1000])
  check(paste0(d, ": 'N jian-cha' claims (if any) == ", n_checks),
        length(ck) == 0 || all(ck == n_checks),
        if (length(ck) && !all(ck == n_checks))
          paste("claimed:", paste(unique(ck[ck != n_checks]), collapse = ",")) else "")
}

## 3. quick-reference section count vs README claim --------------------------
sk = read_doc("SKILL.md")
n_qr = sum(grepl("^### 6\\.[0-9]+ ", sk))
cl_qr = claim_b(read_doc("README.md"), paste0("([0-9]+) ", DUAN))
check(paste0("README: quickref claim present and == ", n_qr),
      length(cl_qr) > 0 && all(cl_qr == n_qr),
      if (length(cl_qr) == 0) "no claim found" else
        if (!all(cl_qr == n_qr))
          paste("claimed:", paste(unique(cl_qr[cl_qr != n_qr]), collapse = ",")) else "")

## 4. anti-pattern table rows vs README claim --------------------------------
sk_lines = readLines(file.path(root, "SKILL.md"), warn = FALSE)
i7 = grep("^## 7\\.", sk_lines); i8 = grep("^## 8\\.", sk_lines)
tbl = sk_lines[(i7 + 1):(i8 - 1)]
n_ap = sum(grepl("^\\| ", tbl)) - 2          # minus header + separator
cl_ap = claim_b(read_doc("README.md"), paste0(FAN, " ([0-9]+) ", TIAO))
check(paste0("README: anti-pattern claim present and == ", n_ap),
      length(cl_ap) > 0 && all(cl_ap == n_ap),
      if (length(cl_ap) == 0) "no claim found" else
        if (!all(cl_ap == n_ap))
          paste("claimed:", paste(unique(cl_ap[cl_ap != n_ap]), collapse = ",")) else "")

## 5. referenced files exist -------------------------------------------------
for (f in c("references/paradigms.md", "assets/data-thinking-2.0.png",
            "scripts/verify_examples.R", "scripts/verify_prompts.R",
            "scripts/check_consistency.R",
            "test-prompts.json", "LICENSE", "CHANGELOG.md", "README.md",
            "SKILL.md")) {
  check(paste0("file exists: ", f), file.exists(file.path(root, f)))
}

## 6. no stale summary claims (outdated counts in README sample output) ------
rm_ = read_doc("README.md")
sm = regmatches(rm_, gregexpr("Summary: ([0-9]+)/([0-9]+) PASS", rm_,
                              perl = TRUE))[[1]]
sm_n = as.integer(sub("^Summary: ([0-9]+)/[0-9]+ PASS$", "\\1", sm))
check(paste0("README: sample summary claims == ", n_cases),
      length(sm_n) == 0 || all(sm_n == n_cases),
      if (length(sm_n) && !all(sm_n == n_cases))
        paste("claimed:", paste(unique(sm_n[sm_n != n_cases]), collapse = ",")) else "")
check("SKILL.md: no bare separate( (superseded)",
      !grepl("[^_]separate\\(", sk))

## summary -------------------------------------------------------------------
cat(sprintf("\nSummary: %d check(s), %d failure(s)\n", total, failures))
if (failures > 0) quit(status = 1)
