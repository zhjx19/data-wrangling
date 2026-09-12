#!/usr/bin/env Rscript
# verify_examples.R -- one-click regression for the tidy-data skill.
#
# Runs the 8 paradigm code templates from SKILL.md + the capstone case,
# proving the framework code runs on the current tidyverse version.
# Re-run after any change to SKILL.md code blocks.
#
# ASCII-only on purpose: this script must run under any locale (a broken
# LC_CTYPE garbles non-ASCII source and kills parsing mid-file -- the same
# pitfall documented in the data-cleaning skill).
#
# The script itself follows the R iron rules: = assignment, |> pipe,
# \(x) anonymous functions, .by grouping.
#
# Usage (any CWD):
#   Rscript --vanilla scripts/verify_examples.R
# Exit code: 0 = all PASS; 1 = any FAIL.
suppressPackageStartupMessages({
  library(tidyverse)
  library(slider)
})

run_case = \(name, code) {
  status = tryCatch(
    { force(code); "PASS" },
    error = \(e) paste("FAIL:", conditionMessage(e))
  )
  cat(sprintf("[%s] %s\n", status, name))
  setNames(status, name)
}

results = c(
  ## ---- Paradigm 1: info-in-column-names -> longer (.value + names_pattern)
  run_case("P1 pivot_longer(.value)", {
    df = data.frame(
      id = 1:2,
      daw_1 = c(1, 0), zda_1 = c(10, 20), da_1 = c(5, 6),
      daw_2 = c(0, 1), zda_2 = c(30, 40), da_2 = c(7, 8)
    )
    out = df |>
      mutate(id = row_number()) |>
      pivot_longer(-id, names_pattern = "(.*)_(\\d)", names_to = c(".value", "grp")) |>
      mutate(adl = if_else(daw == 1, zda, da)) |>
      pivot_wider(id_cols = id, names_from = grp, values_from = c(daw, zda, da, adl))
    stopifnot(nrow(out) == 2, "adl_1" %in% names(out))
    out
  }),

  ## ---- Paradigm 2: grouped summarise ----
  run_case("P2 summarise(.by)", {
    df = tibble(group = c("A", "A", "B"), x = c(1, 3, 5))
    out = df |> summarise(n = n(), mean_x = mean(x, na.rm = TRUE), .by = group)
    stopifnot(nrow(out) == 2, out$n[1] == 2, out$mean_x[2] == 5)
    out
  }),

  ## ---- Paradigm 3: grouped mutate (mom/yoy; arrange before lag) ----
  run_case("P3 mutate(.by) lag mom/yoy", {
    df = expand.grid(region = c("A", "B"), month = 1:12) |>
      mutate(sales = round(runif(24, 50, 150), 0))
    out = df |>
      arrange(region, month) |>
      mutate(
        mom = (sales / lag(sales) - 1),
        yoy = (sales / lag(sales, 12) - 1),
        .by = region
      )
    stopifnot(nrow(out) == 24, is.na(out$mom[1]), is.na(out$yoy[13]))
    out
  }),

  ## ---- Paradigm 4: group-level filter(all(), .by) + row-level if_all ----
  run_case("P4 filter(all,.by) + if_all", {
    df = tibble(
      g = c("A", "A", "A", "B", "B", "B"),
      x = c(1, 2, 3, 1, NA, 3), y = c(1, 1, 1, 1, 1, 1)
    )
    grp = df |> filter(all(!is.na(x)), .by = g)                 # B has NA -> drop whole group
    rowok = df |> filter(if_all(c(x, y), \(v) !is.na(v)), .by = g)  # row-level multi-col
    stopifnot(all(grp$g == "A"), !any(is.na(rowok$x)))
    TRUE
  }),

  ## ---- Paradigm 5: nest + map grouped join ----
  run_case("P5 nest+map grouped join", {
    df1 = tibble(Date = c("2026-01-01", "2026-01-01", "2026-01-02"),
                 ID = c(1, 2, 3), v = c(1, 2, 3))
    df2 = tibble(ID = 1:3, Salary = c(10, 20, 30))
    out = df1 |>
      nest(.by = Date) |>
      mutate(data = map(data, \(d) right_join(d, df2, by = "ID"))) |>
      unnest(data) |>
      replace_na(list(Salary = 0))
    stopifnot(nrow(out) == 6)   # 3 employees per date
    out
  }),

  ## ---- Paradigm 6: accumulate length alignment (x[-1] + .init) ----
  run_case("P6 accumulate alignment", {
    df = tibble(price_idx = c(105, 102, 108, 101))
    out = df |> mutate(base_idx = accumulate(price_idx[-1], \(x, y) x * y / 100, .init = 100))
    stopifnot(nrow(out) == 4, out$base_idx[1] == 100, out$base_idx[2] == 102)
    out
  }),

  ## ---- Paradigm 7: slide_dbl rolling window (.complete = TRUE) ----
  run_case("P7 slide_dbl .complete=TRUE", {
    df = tibble(x = 1:10)
    out = df |> mutate(rolling = slide_dbl(x, mean, .before = 2, .complete = TRUE))
    stopifnot(nrow(out) == 10, is.na(out$rolling[1]), out$rolling[3] == 2)
    out
  }),

  ## ---- Paradigm 8: non-equi join join_by(closest) ----
  run_case("P8 join_by(closest)", {
    df = tibble(active_hours = c(30, 90, 200))
    lookup = tibble(hours = c(0, 50, 100, 300), coef = c(1, 2, 3, 4))
    out = df |> left_join(lookup, join_by(closest(active_hours >= hours)))
    stopifnot(nrow(out) == 3, all(out$coef == c(1, 2, 3)))
    out
  }),

  ## ---- Paradigm 4 extension: negated if_any NA-propagation trap ----
  run_case("P4x negated if_any NA trap (coalesce guard)", {
    df = tibble(
      region = c("East", NA, "North", "North"),
      item   = c("A", "B", "Total", "C")   # one summary row to strip
    )
    # naive negated filter: region-NA row yields NA -> silently dropped
    naive = df |> filter(!if_any(where(is.character), \(x) str_detect(str_squish(x), "^Total$")))
    # guarded: coalesce NA -> "" before matching
    safe = df |> filter(!if_any(where(is.character),
                                \(x) str_detect(str_squish(coalesce(x, "")), "^Total$")))
    stopifnot(nrow(naive) == 2, nrow(safe) == 3)  # naive loses the region-NA row
    safe
  }),

  ## ---- Paradigm 6 extension: grouped accumulate (.by per-group recursion) --
  run_case("P6x grouped accumulate (.by)", {
    df = tibble(
      region = c("A", "A", "A", "B", "B"),   # unbalanced group sizes
      year   = c(1, 2, 3, 1, 2),
      invest = c(20, 30, 25, 50, 40)
    )
    out = df |>
      arrange(region, year) |>
      mutate(K = accumulate(invest[-1], \(x, y) x * 0.95 + y,
                            .init = first(invest)), .by = region)
    # each region starts from ITS OWN first invest; no cross-region leakage
    stopifnot(
      out$K[out$region == "A"][1] == 20,
      abs(out$K[out$region == "A"][2] - (20 * 0.95 + 30)) < 1e-9,
      out$K[out$region == "B"][1] == 50,
      abs(out$K[out$region == "B"][2] - (50 * 0.95 + 40)) < 1e-9,
      nrow(out) == 5
    )
    out
  }),

  ## ---- Quick-reference 6.13-6.16: renamed keys / split / slice_max / complete
  run_case("P11 quickref 6.13-6.16", {
    l = tibble(id = c("01-A001", "02-B002"))
    r = tibble(cust_id = c("01-A001", "02-B002"), score = c(9, 8))
    j = l |> left_join(r, by = c("id" = "cust_id"))            # 6.13 renamed keys
    stopifnot(nrow(j) == 2, all(!is.na(j$score)))
    s = l |> separate_wider_delim(id, delim = "-", names = c("area", "code"))
    stopifnot(identical(names(s), c("area", "code")), s$area[1] == "01")  # 6.14
    d = tibble(cust = c("x", "x", "y"), dt = c(1, 3, 2), v = 1:3)
    sm = d |> slice_max(dt, n = 1, by = cust)                  # 6.15 latest per key
    stopifnot(nrow(sm) == 2, sm$dt[sm$cust == "x"] == 3)
    g = tibble(region = c("A", "B"), month = c(1, 3), sales = c(10, 30))
    cg = g |> complete(region, month = 1:3, fill = list(sales = 0))       # 6.16
    stopifnot(nrow(cg) == 6, sum(cg$sales, na.rm = TRUE) == 40)
    # 6.13 suffix: same-named columns get explicit suffixes, not silent .x/.y
    sj = tibble(id = 1, v = 5) |> left_join(tibble(id = 1, v = 2), by = "id",
                                            suffix = c("_ord", "_cust"))
    stopifnot(identical(names(sj), c("id", "v_ord", "v_cust")))
    cg
  }),

  ## ---- Quick-reference 6.17: rank family tie semantics ----------------------
  run_case("P13 rank family tie semantics", {
    x = c(10, 10, 20)
    stopifnot(
      all(min_rank(x) == c(1, 1, 3)),        # ties share rank, then skip
      all(dense_rank(x) == c(1, 1, 2)),      # ties share rank, no skip
      all(row_number(x) == c(1, 2, 3))       # forced sequence
    )
    # grouped rank (paradigm 3 territory): sales 10,30,20 -> desc ranks 3,1,2
    df = tibble(store = c("A", "A", "A", "B"), sales = c(10, 30, 20, 5))
    out = df |> mutate(rk = min_rank(-sales), .by = store)
    stopifnot(out$rk[out$store == "A"] == c(3, 1, 2), out$rk[out$store == "B"] == 1)
    out
  }),

  ## ---- Paradigm 7 extension: grouped slide_dbl (.by per-group windows) -----
  run_case("P12 grouped slide_dbl (.by)", {
    df = tibble(
      store = c("A", "A", "A", "B", "B", "B"),
      day   = c(1, 2, 3, 1, 2, 3),
      sales = c(10, 20, 30, 100, 200, 300)
    )
    out = df |>
      arrange(store, day) |>
      mutate(r3 = slide_dbl(sales, mean, .before = 2, .complete = TRUE), .by = store)
    # per-group windows: A row3 = mean(10,20,30)=20; B row3 = mean(100,200,300)=200.
    # If windows leaked across stores, B row3 would be mean(20,30,100)=50.
    stopifnot(
      is.na(out$r3[1]), is.na(out$r3[2]), out$r3[3] == 20,
      is.na(out$r3[4]), is.na(out$r3[5]), out$r3[6] == 200,
      nrow(out) == 6
    )
    out
  })
)

## ---- Capstone case: store sales (multi-paradigm pipeline) ----
cat("\n=== Capstone: store sales (wide->mom->group filter->cumulate->rank) ===\n")
set.seed(42)
n = 5
wide = tibble(
  store = paste0("S", 1:n),
  region = rep(c("East", "North"), length.out = n),
  m1 = round(runif(n, 80, 120)), m2 = round(runif(n, 80, 120)),
  m3 = round(runif(n, 80, 120)), m4 = round(runif(n, 80, 120)),
  m5 = round(runif(n, 80, 120)), m6 = round(runif(n, 80, 120))
)
wide$m3[3] = NA  # one store missing one month (for group-level filtering)

# (1) Paradigm 1: info-in-column-names -> longer
long = wide |>
  pivot_longer(-c(store, region), names_pattern = "m(\\d)", names_to = "month", values_to = "sales")
# (2) Paradigm 3: grouped mom (arrange first to keep lag order)
long = long |>
  arrange(store, month) |>
  mutate(mom = sales / lag(sales) - 1, .by = store)
# (3) Paradigm 4: group-level filter -- drop stores with any missing month
clean = long |> filter(all(!is.na(sales)), .by = store)
stopifnot(setequal(clean$store, c("S1", "S2", "S4", "S5")), nrow(clean) == 24)
# (4) Paradigm 6: accumulate base (K_t = K_{t-1}*0.9 + sales_t)
acc = long |>
  filter(store == "S1") |>
  mutate(cum_base = accumulate(sales[-1], \(x, y) x * 0.9 + y, .init = 100))
stopifnot(nrow(acc) == 6, acc$cum_base[1] == 100, acc$cum_base[2] == round(100 * 0.9 + acc$sales[2]))
# (5) Paradigm 2: grouped summarise + rank
summ = clean |>
  summarise(total_sales = sum(sales, na.rm = TRUE), avg_mom = mean(mom, na.rm = TRUE), .by = store) |>
  mutate(rk = min_rank(-total_sales)) |>
  arrange(rk)
stopifnot(nrow(summ) == 4, summ$rk[1] == 1)
print(summ)

## ---- Summary ----
fails = names(results)[results != "PASS"]
cat(sprintf("\n=== Summary: %d/%d PASS ===\n", sum(results == "PASS"), length(results)))
if (length(fails) > 0) {
  for (f in fails) cat("FAIL:", f, "->", results[[f]], "\n")
  quit(status = 1)
}
quit(status = 0)
