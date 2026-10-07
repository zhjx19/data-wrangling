#!/usr/bin/env Rscript
# verify_snippets.R -- real-run census of EVERY ```r block in SKILL.md and
# references/paradigms.md (37 source blocks -> 47 executable cases).
#
# Why this file is ASCII-only while its case table is not: the fixtures keep the
# docs' own column names (they are Chinese), so the census runs the documented
# code as written. Parsing non-ASCII R source depends on the locale, so the
# launcher reads the case table with an EXPLICIT UTF-8 encoding instead of letting
# the parser guess. Same trick, same reason as the byte-level workaround documented
# in the sibling scripts -- except here it costs nothing, because the launcher
# itself has no non-ASCII in it.
#
# Complements verify_examples.R: that one runs 15 representative cases and is the
# gate for day-to-day edits; this one runs all 47 and is the evidence that no code
# block in the docs is dead. Found 4 real doc bugs on its first run (see
# VERIFICATION.md).
#
# Iron rules: = assignment, |> pipe, \(x) anonymous, .by grouping.
# Usage (any CWD):
#   Rscript --vanilla scripts/verify_snippets.R            # 47 cases
#   Rscript --vanilla scripts/verify_snippets.R --csv      # + snippet-audit.csv
# Exit code: 0 = all PASS; 1 = any FAIL.

suppressPackageStartupMessages({
  library(tidyverse)
  library(slider)
  library(lubridate)          # the .by = year(...) case needs it
})
options(readr.show_col_types = FALSE)

# repo root, derived from this script's own path (works from any CWD)
args_all = commandArgs(trailingOnly = FALSE)
me = sub("^--file=", "", args_all[grep("^--file=", args_all)])
ROOT = if (length(me) == 1) normalizePath(file.path(dirname(me), "..")) else getwd()

CASES = file.path(ROOT, "scripts", "snippets-cases.R")
if (!file.exists(CASES)) stop("case table not found: ", CASES, call. = FALSE)

# explicit UTF-8: never let the locale decide how this file is parsed
eval(parse(text = readLines(CASES, encoding = "UTF-8", warn = FALSE),
           encoding = "UTF-8"), envir = globalenv())

st = unname(results)
res_df = tibble(
  block = names(results),
  status = if_else(startsWith(st, "PASS"), "PASS", "FAIL"),
  detail = if_else(startsWith(st, "PASS"), "", st)
)
n_pass = sum(res_df$status == "PASS")
n_fail = nrow(res_df) - n_pass

if ("--csv" %in% commandArgs(trailingOnly = TRUE)) {
  out = file.path(ROOT, "snippet-audit.csv")
  write_csv(res_df, out)
  cat(sprintf("wrote %s\n", out))
}

cat(sprintf("\n=== Summary: %d/%d PASS ===\n", n_pass, nrow(res_df)))
if (n_fail > 0) {
  cat("Failed cases:\n")
  for (i in which(res_df$status == "FAIL")) {
    cat(sprintf("  %s\n      %s\n", res_df$block[i], res_df$detail[i]))
  }
  quit(status = 1)
}
quit(status = 0)
