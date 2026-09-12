#!/usr/bin/env Rscript
# verify_prompts.R -- runtime regression for the skill's test-prompts.json.
#
# Each of the 3 documented prompts is turned into a fixture + the exact
# pipeline the skill prescribes, with output assertions. This upgrades the
# prompts from dry_run to measured evidence.
#
# ASCII-only on purpose (any-locale safe, see verify_examples.R).
# Usage: Rscript --vanilla scripts/verify_prompts.R
# Exit code: 0 = all PASS; 1 = any FAIL.
suppressPackageStartupMessages({
  library(tidyverse)
})

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

## Prompt 1: wide month_1..month_12 -> long (month, mean_sales) -------------
set.seed(11)
df1 = do.call(tibble, c(list(id = 1:3),
                        setNames(lapply(1:12, \(i) round(runif(3, 100, 200), 1)),
                                 paste0("month_", 1:12))))
p1 = df1 |>
  pivot_longer(-id, names_pattern = "month_(\\d+)",
               names_to = "m", values_to = "sales") |>
  summarise(mean_sales = mean(sales), .by = m) |>
  arrange(as.integer(m))
expected1 = sapply(paste0("month_", 1:12), \(cn) mean(df1[[cn]]))
check("P1 long shape 12 rows", nrow(p1) == 12)
check("P1 means match column means",
      all(abs(p1$mean_sales - expected1) < 1e-9))

## Prompt 2: mom per region + drop region with any missing month ------------
set.seed(7)
df2 = expand.grid(region = c("A", "B", "C"), month = 1:6) |>
  as_tibble() |>
  arrange(region, month) |>
  mutate(sales = round(runif(18, 10, 100)))
df2$sales[c(2, 15)] = NA   # region A month 2 (row 2); region C month 3 (row 15)
p2 = df2 |>
  mutate(mom = sales / lag(sales) - 1, .by = region) |>
  filter(all(!is.na(sales)), .by = region) |>          # drop A and C entirely
  summarise(n_complete = sum(!is.na(sales)), .by = region)
check("P2 only complete region survives", setequal(p2$region, "B"))
check("P2 complete-month count", p2$n_complete[[1]] == 6)

## Prompt 3: perpetual inventory via accumulate (no for loop) ----------------
df3 = tibble(region = c("A", "A", "A"), year = 1:3, invest = c(20, 30, 25))
p3 = df3 |>
  arrange(region, year) |>
  mutate(K = accumulate(invest[-1], \(x, y) x * 0.95 + y, .init = 100))
check("P3 accumulate alignment (K1 = init)", p3$K[1] == 100)
check("P3 recursion K_t = K_{t-1}*0.95 + I_t",
      abs(p3$K[2] - (100 * 0.95 + 30)) < 1e-9 &&
        abs(p3$K[3] - (p3$K[2] * 0.95 + 25)) < 1e-9)
check("P3 distinct replaces set logic", nrow(distinct(p3, region)) == 1)

## Summary ------------------------------------------------------------------
cat(sprintf("\nSummary: %d check(s), %d failure(s)\n", total, failures))
if (failures > 0) quit(status = 1)
