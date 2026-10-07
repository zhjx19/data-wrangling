# snippets-cases.R -- the case table for scripts/verify_snippets.R. NOT runnable
# on its own: the ASCII launcher reads this file with an explicit UTF-8 encoding
# and evaluates it. That split exists on purpose -- these fixtures keep the DOCS'
# own column names (销售时间 / 门店 / 累计基数 ...), so the census really runs the
# code as written; and the launcher stays ASCII so nothing here can trip a
# non-UTF-8 locale at parse time (the landmine documented in verify_examples.R).
#
# Case labels cite the doc section, not a line number: line numbers rot, section
# names do not.
#
# One case = one doc block (or one statement of a multi-line block) on a concrete
# fixture. Template placeholders (函数/计算式/条件/分组列/序列/启动值) are substituted
# with real expressions and marked [template]. Assertions encode the DOCUMENTED
# intent; a FAIL is evidence of a doc bug until dispositioned as a fixture gap.
#
# Iron rules: = assignment, |> pipe, \(x) anonymous, .by grouping.

# informative assertion helper (stopifnot failures are cryptic)
expect = \(cond, msg) {
  if (!isTRUE(cond)) stop(msg, call. = FALSE)
  invisible(TRUE)
}

run_case = \(name, code) {
  status = tryCatch(
    { force(code); "PASS" },
    error = \(e) paste0("FAIL: ", conditionMessage(e))
  )
  ok = startsWith(status, "PASS")
  cat(sprintf("[%s] %s\n", if (ok) "PASS" else "FAIL", name))
  if (!ok) cat(sprintf("        %s\n", status))
  setNames(status, name)
}

results = c(

# ===== SKILL.md 6.1-6.4: core grouped verbs =====
run_case("B01 SKILL.md summarise(.by)", {
  df = tibble(group = c("A", "A", "B"), x = c(1, 3, 5))
  out = df |> summarise(n = n(), mean_x = mean(x, na.rm = TRUE), .by = group)
  stopifnot(identical(out$group, c("A", "B")), nrow(out) == 2,
            out$n[1] == 2, out$n[2] == 1,
            out$mean_x[1] == 2, out$mean_x[2] == 5)
  TRUE
}),

run_case("B02 SKILL.md mutate lag pct (.by)", {
  df = tibble(group = c("A", "A", "B"), x = c(1, 2, 4))
  out = df |> mutate(pct = (x - lag(x)) / lag(x) * 100, .by = group)
  stopifnot(is.na(out$pct[1]), out$pct[2] == 100, is.na(out$pct[3]))
  TRUE
}),

run_case("B03 SKILL.md filter(x == max(x), .by)", {
  df = tibble(group = c("A", "A", "B"), x = c(1, 5, 3))
  out = df |> filter(x == max(x), .by = group)
  stopifnot(nrow(out) == 2, out$x[1] == 5, out$x[2] == 3)
  TRUE
}),

run_case("B04a SKILL.md filter(all(x > 0), .by)", {
  df = tibble(g = c("A", "A", "B"), x = c(1, 2, -1))
  out = df |> filter(all(x > 0), .by = g)
  stopifnot(nrow(out) == 2, all(out$g == "A"))
  TRUE
}),

run_case("B04b SKILL.md filter miss-rate < 50% (boundary)", {
  # A: 1/4 missing -> kept; B: all missing -> dropped; C: none -> kept;
  # D: exactly 0.5 missing -> dropped (strict <)
  df = tibble(g = rep(c("A", "B", "C", "D"), c(4, 2, 2, 2)),
              x = c(1, 2, 3, NA, NA, NA, 7, 8, NA, 5))
  out = df |> filter(mean(is.na(x)) < 0.5, .by = g)
  stopifnot(setequal(out$g, c("A", "C")), nrow(out) == 6)
  TRUE
}),

# ===== SKILL.md 6.5-6.7: across + reshape =====
run_case("B05a SKILL.md across scale", {
  df = tibble(id = 1:3, a = c(1, 2, 3), b = c(10, 20, 30))
  out = df |> mutate(across(where(is.numeric), \(x) scale(x)[, 1]))
  stopifnot(abs(mean(out$a)) < 1e-9, abs(mean(out$b)) < 1e-9)
  TRUE
}),

run_case("B05b SKILL.md across summarise starts_with", {
  df = tibble(id = 1:2, sales_1 = c(1, 2), sales_2 = c(3, 4), other = c(9, 9))
  out = df |> summarise(across(starts_with("sales_"), \(x) mean(x, na.rm = TRUE)))
  stopifnot(identical(names(out), c("sales_1", "sales_2")),
            out$sales_1 == 1.5, out$sales_2 == 3.5)
  TRUE
}),

run_case("B06 SKILL.md long->op->wide [template: 函数(val)]", {
  df = tibble(id = 1:2, m1 = c(1, 2), m2 = c(3, 4))
  out = df |>
    pivot_longer(-id, names_to = "var", values_to = "val") |>
    mutate(val = val * 2, .by = c(id, var)) |>   # 函数(val) substituted
    pivot_wider(names_from = var, values_from = val)
  stopifnot(nrow(out) == 2, out$m1[1] == 2, out$m2[2] == 8)
  TRUE
}),

run_case("B07a SKILL.md wide->long (-固定列)", {
  df = tibble(固定列 = c("p", "q"), month1 = c(1, 2), month2 = c(3, 4))
  out = df |> pivot_longer(-固定列, names_to = "k", values_to = "v")
  stopifnot(nrow(out) == 4,
            identical(out$k, rep(c("month1", "month2"), 2)),
            identical(out$v, c(1, 3, 2, 4)))
  TRUE
}),

run_case("B07b SKILL.md long->wide names_prefix", {
  df = tibble(id = c(1, 1, 2, 2), k = c("a", "b", "a", "b"), v = 1:4)
  out = df |> pivot_wider(names_from = k, values_from = v, names_prefix = "pre_")
  stopifnot(identical(names(out), c("id", "pre_a", "pre_b")),
            out$pre_a[1] == 1, out$pre_b[1] == 2, out$pre_a[2] == 3)
  TRUE
}),

run_case("B07c SKILL.md names_pattern .value", {
  df = tibble(id = 1:2, a_1 = c(1, 2), a_2 = c(3, 4), b_1 = c(5, 6), b_2 = c(7, 8))
  out = df |> pivot_longer(-id, names_pattern = "(.*)_(\\d+)",
                           names_to = c(".value", "num"))
  # doc 只声明 .value 拆列，不断言行序；按 id+num 对齐取值（顺序无关）
  r1 = out |> filter(id == 1, num == "1")
  r2 = out |> filter(id == 1, num == "2")
  stopifnot(all(c("a", "b", "num") %in% names(out)), nrow(out) == 4,
            identical(sort(out$a), c(1, 2, 3, 4)), identical(sort(out$b), c(5, 6, 7, 8)),
            r1$a == 1, r1$b == 5, r2$a == 3, r2$b == 7)
  TRUE
}),

run_case("B07d SKILL.md pivot_wider 两坑 + 组内唯一 id", {
  df = tibble(x = 1:6, y = c("A", "A", "B", "B", "C", "C"),
              z = c(2.13, 3.65, 1.88, 2.30, 6.55, 4.21))
  # 坑 1：带着唯一 ID 列 -> 行数不压缩，填 NA
  w1 = df |> pivot_wider(names_from = y, values_from = z)
  stopifnot(nrow(w1) == 6, is.na(w1$A[3]), is.na(w1$B[1]))
  # 坑 2：无 ID 列 -> 值不唯一识别 -> 列表列
  w2 = df[-1] |> pivot_wider(names_from = y, values_from = z)
  stopifnot(nrow(w2) == 1, is.list(w2$A), all(map_int(w2$A, length) == 2))
  # 正解：先造组内唯一识别列
  w3 = df[-1] |> mutate(n = row_number(), .by = y) |>
    pivot_wider(names_from = y, values_from = z)
  stopifnot(nrow(w3) == 2, identical(names(w3), c("n", "A", "B", "C")),
            w3$A[1] == 2.13, w3$A[2] == 3.65, w3$C[2] == 4.21)
  # 等价：保留原 ID 列 + 显式 id_cols
  w4 = df |> mutate(n = row_number(), .by = y) |>
    pivot_wider(names_from = y, values_from = z, id_cols = n)
  stopifnot(nrow(w4) == 2, identical(names(w4), c("n", "A", "B", "C")))
  # 特例：不规则通讯录（ASCII 等价夹具）
  contacts = tribble(
    ~field, ~value,
    "name", "p1", "company", "c1",
    "name", "p2", "company", "c2", "email", "e2@x.com",
    "name", "p3")
  w5 = contacts |> mutate(ID = cumsum(field == "name")) |>
    pivot_wider(names_from = field, values_from = value)
  stopifnot(nrow(w5) == 3, identical(names(w5), c("ID", "name", "company", "email")),
            w5$name == c("p1", "p2", "p3"), is.na(w5$email[3]))
  TRUE
}),

# ===== SKILL.md 6.8-6.10: nest / accumulate / slide =====
run_case("B08a SKILL.md nest+map [template: 对子数据框的操作]", {
  df = tibble(group = c("A", "A", "B", "B"), x = c(1, 5, 2, 8))
  out = df |>
    nest(.by = group) |>
    mutate(data = map(data, \(d) d |> filter(x > mean(x)))) |>  # template sub
    unnest(data)
  stopifnot(nrow(out) == 2, setequal(out$x, c(5, 8)))   # A:5  B:8
  TRUE
}),

run_case("B08b SKILL.md reframe quantile", {
  df = tibble(group = c("A", "A", "B"), x = c(1, 2, 3))
  out = df |> reframe(qs = quantile(x, c(0.25, 0.75)), .by = group)
  stopifnot(nrow(out) == 4,
            out$qs[1] == 1.25, out$qs[2] == 1.75, out$qs[3] == 3, out$qs[4] == 3)
  TRUE
}),

run_case("B09 SKILL.md cumsum + accumulate + grouped", {
  df = tibble(x = c(1, 2, 3), invest = c(20, 30, 25), region = c("A", "A", "B"))
  o1 = df |> mutate(cum = cumsum(x))
  o2 = df |> mutate(cum = accumulate(x[-1], ~ .x * 0.95 + .y, .init = first(x)))
  o3 = df |> mutate(K = accumulate(invest[-1], ~ .x * 0.95 + .y,
                                   .init = first(invest)), .by = region)
  stopifnot(o1$cum[3] == 6,
            o2$cum[1] == 1, abs(o2$cum[2] - 2.95) < 1e-9,
            o3$K[1] == 20, o3$K[3] == 25, nrow(o3) == 3)
  TRUE
}),

run_case("B10 SKILL.md slide_dbl ungrouped + grouped .by", {
  df = tibble(x = 1:9, sales = 2 * (1:9),
              store = rep(c("A", "B"), length.out = 9))
  o1 = df |> mutate(rm = slide_dbl(x, mean, .before = 2, .complete = TRUE))
  o2 = df |> mutate(rm = slide_dbl(sales, mean, .before = 2, .complete = TRUE),
                    .by = store)
  # ungrouped: first 2 windows incomplete
  stopifnot(is.na(o1$rm[1]), is.na(o1$rm[2]), o1$rm[3] == 2)
  # grouped windows restart per store (store A = rows 1,3,5,... ; B = 2,4,6,...)
  stopifnot(is.na(o2$rm[1]), is.na(o2$rm[2]), is.na(o2$rm[3]), is.na(o2$rm[4]),
            o2$rm[5] == mean(c(2, 6, 10)),    # A pos3 = rows 1,3,5
            o2$rm[6] == mean(c(4, 8, 12)))    # B pos3 = rows 2,4,6
  TRUE
}),

# ===== SKILL.md 6.11-6.13: joins =====
run_case("B11 SKILL.md join_by(closest)", {
  df = tibble(value = c(5, 55, 105))
  lookup = tibble(threshold = c(0, 50, 100), tier = c("lo", "mid", "hi"))
  out = df |> left_join(lookup, join_by(closest(value >= threshold)))
  stopifnot(nrow(out) == 3, identical(out$tier, c("lo", "mid", "hi")))
  TRUE
}),

run_case("B12 SKILL.md map over columns (mean line)", {
  df = tibble(y = c(1, 2, 3, 4), x1 = c(2, 1, 4, 3), x2 = c(4, 3, 2, 1))
  out = tibble(col = names(df[-1]), mean = map_dbl(df[-1], \(x) mean(x, na.rm = TRUE)))
  stopifnot(nrow(out) == 2, out$mean[out$col == "x1"] == 2.5)
  TRUE
}),

run_case("B12b SKILL.md lm(y ~ x, data = df) per column", {
  df = tibble(y = c(1, 2, 3, 4), x1 = c(2, 1, 4, 3), x2 = c(4, 3, 2, 1))
  fits = tibble(col = names(df[-1]), fit = map(df[-1], \(x) lm(y ~ x, data = df)))
  slopes = map_dbl(fits$fit, \(m) coef(m)[[2]])
  # df has no column x: x resolves from the lambda env -> fits must differ
  stopifnot(nrow(fits) == 2, abs(slopes[1] - 0.6) < 1e-9, abs(slopes[2] + 1) < 1e-9)
  TRUE
}),

run_case("B13 SKILL.md renamed keys + suffix", {
  df = tibble(id = c("01-A001", "02-B002"), score = c(7, 6))
  y1 = tibble(cust_id = c("01-A001", "02-B002"), score = c(9, 8))
  j1 = df |> left_join(y1, by = c("id" = "cust_id"))
  stopifnot(nrow(j1) == 2, all(!is.na(j1$score.y)))
  y2 = tibble(id = c("01-A001", "02-B002"), score = c(9, 8))
  j3 = df |> left_join(y2, by = "id", suffix = c("_订单", "_客户"))
  stopifnot(all(c("score_订单", "score_客户") %in% names(j3)),
            j3$score_客户[1] == 9)
  TRUE
}),

run_case("B14 SKILL.md separate_wider_delim + position", {
  df = tibble(编码 = c("01-A001", "02-B002"))
  out = df |> separate_wider_delim(编码, delim = "-", names = c("区号", "编号"))
  stopifnot(identical(names(out), c("区号", "编号")),
            out$区号[1] == "01", out$编号[1] == "A001")
  df3 = tibble(编码 = c("01A001", "02B002"))
  out3 = df3 |> separate_wider_position(编码, widths = c(区号 = 2, 编号 = 4))  # widths 必须命名
  stopifnot(identical(names(out3), c("区号", "编号")),
            nrow(out3) == 2, out3$区号[1] == "01", out3$编号[1] == "A001")
  TRUE
}),

run_case("B15 SKILL.md slice_max + slice_head", {
  df = tibble(客户 = c("x", "x", "y", "z"), 组 = c("g1", "g1", "g2", "g1"),
              时间 = c(3, 3, 2, 5), v = 1:4)
  o1 = df |> slice_max(时间, n = 1, by = 客户)
  o2 = df |> slice_max(时间, n = 1, by = 客户, with_ties = FALSE)
  o3 = df |> slice_head(n = 2, by = 组)
  stopifnot(nrow(o1) == 4,     # tie kept: both x rows
            nrow(o2) == 3,     # tie broken
            nrow(o3) == 3,     # g1 -> rows 1,2 ; g2 -> row 3
            o3$v[1] == 1, o3$v[2] == 2, o3$v[3] == 3)
  TRUE
}),

run_case("B16 SKILL.md complete grid fill 0", {
  df = tibble(地区 = c("东", "西"), 月份 = c(1, 3), 销量 = c(10, 30))
  out = df |> complete(地区, 月份 = 1:12, fill = list(销量 = 0))
  stopifnot(nrow(out) == 24, sum(out$销量) == 40)
  TRUE
}),

run_case("B17 SKILL.md rank family tie semantics", {
  df = tibble(门店 = c("A", "A", "A", "B"), 销量 = c(20, 20, 10, 5))
  o1 = df |> mutate(rk = min_rank(-销量), .by = 门店)      # 1,1,3
  o2 = df |> mutate(rk = dense_rank(-销量), .by = 门店)    # 1,1,2
  o3 = df |> mutate(rk = row_number(-销量), .by = 门店)    # 1,2,3
  stopifnot(identical(o1$rk, c(1L, 1L, 3L, 1L)),
            identical(o2$rk, c(1L, 1L, 2L, 1L)),
            identical(o3$rk, c(1L, 2L, 3L, 1L)))
  TRUE
}),

# ===== paradigms.md blocks 18-36 =====
run_case("B18 paradigms.md .value pivot round-trip", {
  df = data.frame(
    id = 1:2,
    daw_1 = c(1, 0), zda_1 = c(10, 20), da_1 = c(5, 6),
    daw_2 = c(0, 1), zda_2 = c(30, 40), da_2 = c(7, 8))
  out = df |>
    mutate(id = row_number()) |>
    pivot_longer(-id, names_pattern = "(.*)_(\\d)", names_to = c(".value", "grp")) |>
    mutate(adl = if_else(daw == 1, zda, da)) |>
    pivot_wider(id_cols = id, names_from = grp, values_from = c(daw, zda, da, adl))
  stopifnot(nrow(out) == 2, "adl_1" %in% names(out),
            out$adl_1[1] == 10, out$adl_1[2] == 6,   # row1 daw=1 -> zda; row2 daw=0 -> da
            out$adl_2[1] == 7, out$adl_2[2] == 40)
  TRUE
}),

run_case("B19 paradigms.md generic summarise (dup of B01)", {
  df = tibble(group = c("A", "A", "B"), x = c(1, 3, 5))
  out = df |> summarise(n = n(), mean_x = mean(x, na.rm = TRUE), .by = group)
  stopifnot(nrow(out) == 2, out$n[1] == 2, out$mean_x[1] == 2)
  TRUE
}),

run_case("B20 paradigms.md n_distinct + year(.by)", {
  df = tibble(
    社保卡号 = c("a", "a", "b", "b", "b"),
    销售时间 = as.Date(c("2021-03-05", "2021-03-06", "2022-01-01",
                         "2022-01-02", NA)),
    实收金额 = c(100, 200, 150, 50, 999))
  out = df |>
    filter(!if_any(1:2, is.na)) |>
    mutate(年 = year(销售时间)) |>   # .by 只收列名，先算出分组列
    summarise(总次数 = n_distinct(社保卡号, 销售时间),
              总金额 = sum(实收金额),
              .by = 年) |>
    mutate(客单价 = 总金额 / 总次数)
  stopifnot(nrow(out) == 2, sum(out$总金额) == 500,
            setequal(out$年, c(2021, 2022)),
            setequal(out$客单价, c(100, 150)))
  TRUE
}),

run_case("B21 paradigms.md mutate(new = calc, .by) [template]", {
  df = tibble(g = c("A", "A", "B"), x = c(1, 3, 10))
  out = df |> mutate(中心化值 = x - mean(x), .by = g)   # 计算式, 分组列 substituted
  stopifnot(out$中心化值[1] == -1, out$中心化值[2] == 1, out$中心化值[3] == 0)
  TRUE
}),

run_case("B22 paradigms.md 环比/同比/定基比 lag ratios", {
  dates = seq(as.Date("2020-01-01"), by = "month", length.out = 13)
  sales = c(100, 110, 105, 108, 112, 115, 118, 120, 117, 121, 125, 128, 130)
  df = tibble(地区 = rep(c("华东", "华北"), each = 13),
              日期 = rep(dates, 2),
              销售额 = rep(sales, 2))
  baseDate = as.Date("2020-01-01")
  out = df |>
    mutate(环比 = (销售额 / lag(销售额) - 1),
           同比 = (销售额 / lag(销售额, 12) - 1),
           定基比 = (销售额 / first(销售额[日期 == baseDate]) - 1),
           .by = 地区)
  stopifnot(nrow(out) == 26,
            is.na(out$环比[1]), is.na(out$环比[14]),        # each region's first month
            abs(out$环比[2] - 0.1) < 1e-9,                  # 110/100 - 1
            all(is.na(out$同比[1:12])), !is.na(out$同比[13]),   # lag 12
            out$定基比[1] == 0, abs(out$定基比[14]) < 1e-12)    # base month = 0
  TRUE
}),

run_case("B23 paradigms.md in-group rank (-销售额)", {
  df = tibble(门店 = c("A", "A", "B"), 销售额 = c(10, 8, 5))
  out = df |> mutate(店内排名 = min_rank(-销售额), .by = 门店)
  stopifnot(identical(out$店内排名, c(1L, 2L, 1L)))
  TRUE
}),

run_case("B24a paradigms.md filter(条件, .by) [template]", {
  df = tibble(g = c("A", "A", "B", "B"), x = c(1, 5, 2, -3))
  out = df |> filter(x > 0, .by = g)    # 条件 = x > 0
  stopifnot(nrow(out) == 3)
  TRUE
}),

run_case("B24b paradigms.md filter(all(条件), .by) [template]", {
  df = tibble(g = c("A", "A", "B", "B"), x = c(1, 5, 2, -3))
  out = df |> filter(all(x > 0), .by = g)
  stopifnot(setequal(out$g, "A"), nrow(out) == 2)
  TRUE
}),

run_case("B25a paradigms.md row-level NA drop", {
  df = tibble(g = rep(c("A", "B", "C"), c(3, 3, 2)),
              x = c(1, NA, 5, NA, NA, NA, 7, 8))
  out = df |> filter(!is.na(x), .by = g)
  stopifnot(nrow(out) == 4, !anyNA(out$x))
  TRUE
}),

run_case("B25b paradigms.md group drop if any NA", {
  df = tibble(g = rep(c("A", "B", "C"), c(3, 3, 2)),
              x = c(1, NA, 5, NA, NA, NA, 7, 8))
  out = df |> filter(all(!is.na(x)), .by = g)
  stopifnot(setequal(out$g, "C"), nrow(out) == 2)
  TRUE
}),

run_case("B25c paradigms.md miss-rate < 0.6 group drop", {
  df = tibble(g = rep(c("A", "B", "C"), c(3, 3, 2)),
              x = c(1, NA, 5, NA, NA, NA, 7, 8))
  out = df |> filter(mean(is.na(x)) < 0.6, .by = g)   # A: 1/3 kept; B: 1 dropped; C: 0 kept
  stopifnot(setequal(unique(out$g), c("A", "C")), nrow(out) == 5)
  TRUE
}),

run_case("B26a paradigms.md if_all non-missing keep row", {
  df = tibble(x = c(1, NA, 3, NA), y = c(4, 5, NA, NA), g = c("A", "A", "B", "B"))
  out = df |> filter(if_all(c(x, y), ~ !is.na(.x)), .by = g)
  stopifnot(nrow(out) == 1, out$x[1] == 1, out$y[1] == 4)
  TRUE
}),

run_case("B26b paradigms.md if_any(1:2, is.na) 'delete' row", {
  # doc comment: 前两列任一缺失就删该行 -> kept rows must have BOTH non-missing
  df = tibble(x = c(1, NA, 3, NA), y = c(4, 5, NA, NA), g = c("A", "A", "B", "B"))
  out = df |> filter(!if_any(1:2, is.na), .by = g)   # 条件取反（doc 修复后）
  stopifnot(nrow(out) == 1, out$x[1] == 1, out$y[1] == 4)
  TRUE
}),

run_case("B27 paradigms.md nest+map+unnest [template: 函数]", {
  df = tibble(g = c("A", "A", "B"), x = c(1, 3, 10))
  out = df |>
    nest(.by = g) |>
    mutate(data = map(data, \(d) tibble(mean_x = mean(d$x)))) |>   # 函数 substituted
    unnest(data)
  stopifnot(nrow(out) == 2, out$mean_x[1] == 2, out$mean_x[2] == 10)
  TRUE
}),

run_case("B28 paradigms.md nest + right_join per group", {
  df1 = tibble(Date = as.Date(c("2022-01-01", "2022-01-01", "2022-01-02")),
               ID = c("A", "B", "A"))
  df2 = tibble(ID = c("A", "B", "C"), Salary = c(100, NA, 300))
  out = df1 |>
    nest(.by = Date) |>
    mutate(data = map(data, ~ right_join(.x, df2, by = "ID"))) |>
    unnest(data) |>
    replace_na(list(Salary = 0))
  stopifnot(nrow(out) == 6, !anyNA(out$Salary), sum(out$Salary) == 800)
  TRUE
}),

run_case("B29 paradigms.md list.files + str_extract + nest + map_dfr", {
  dir_path = file.path(tempdir(), "audit_b29")
  dir.create(file.path(dir_path, "data"), showWarnings = FALSE, recursive = TRUE)
  writeLines(c("id,val", "1,10", "2,20"), file.path(dir_path, "data", "a1.csv"))
  writeLines(c("id,val", "3,30"), file.path(dir_path, "data", "a2.csv"))
  writeLines(c("id,val", "4,40"), file.path(dir_path, "data", "b1.csv"))
  old = setwd(dir_path)
  out = tryCatch({
    tibble(files = list.files("data/", full.names = TRUE)) |>
      mutate(grp = str_extract(files, "(?<=/)[a-z](?=\\d)")) |>
      nest(.by = grp, .key = "files") |>
      mutate(data = map(files, ~ map_dfr(.x$files, read_csv)))
  }, finally = setwd(old))
  stopifnot(nrow(out) == 2, sum(map_int(out$data, nrow)) == 4)
  TRUE
}),

run_case("B30 paradigms.md accumulate length+1 note [template]", {
  df = tibble(序列 = c(105, 98, 102))
  启动值 = 100
  out = df |> mutate(累计结果 = accumulate(序列[-1], ~ .x * .y / 100, .init = 启动值))
  stopifnot(nrow(out) == 3, out$累计结果[1] == 100,
            out$累计结果[2] == 98, abs(out$累计结果[3] - 99.96) < 1e-9)
  TRUE
}),

run_case("B31 paradigms.md chained indices + capital stock", {
  df = tibble(价格指数 = c(100, 102, 99), 固定资产投资 = c(50, 60, 55))
  out = df |>
    mutate(基期指数 = accumulate(价格指数[-1], ~ .x * .y / 100, .init = 100),
           资本存量 = accumulate(固定资产投资[-1], ~ .x * (1 - 0.05) + .y,
                                 .init = first(固定资产投资)))
  stopifnot(abs(out$基期指数[3] - 100.98) < 1e-9,
            abs(out$资本存量[2] - 107.5) < 1e-9,
            abs(out$资本存量[3] - 157.125) < 1e-9)
  TRUE
}),

run_case("B32 paradigms.md library(slider) + slide() signature", {
  library(slider)
  out = slide(1:3, sum, .before = 1, .complete = TRUE)
  ph = if (length(out) < 1) "<empty>"
       else if (is.null(out[[1]])) "NULL"
       else paste0(typeof(out[[1]]), ": ", out[[1]])
  cat(sprintf("        .complete placeholder = %s\n", ph))
  computed = Filter(\(z) is.numeric(z), out)
  expect(length(computed) == 2 && computed[[1]] == 3 && computed[[2]] == 5, sprintf(
    "complete windows wrong (want sums 3,5); full result: %s",
    paste(vapply(out, \(z) if (is.null(z)) "NULL" else as.character(z[1]), ""), collapse = " | ")))
  TRUE
}),

run_case("B33 paradigms.md slide nested add/drop count labels", {
  # group sizes 3/1/2 so each nested df is a plain char column (not list-col)
  df = tibble(
    from = rep("BJ", 6),
    year = rep(2019:2021, c(3, 1, 2)),
    目的地 = c("上海", "广州", "成都", "成都", "成都", "重庆"))
  out = df |>
    nest(.by = c(from, year)) |>
    mutate(result = slide(data, \(x) {
        if (length(x) < 2) return(NA)
        c(减少 = setdiff(x[[1]]$目的地, x[[2]]$目的地) |> length(),
          增加 = setdiff(x[[2]]$目的地, x[[1]]$目的地) |> length())
      }, .before = 1, .complete = TRUE))
  stopifnot(nrow(out) == 3)
  computed = Filter(\(z) is.numeric(z) && !is.null(names(z)) &&
                      "减少" %in% names(z), out$result)
  expect(length(computed) == 2, sprintf(
    "expected 2 computed windows, got %d (placeholder handling differs?)", length(computed)))
  r2 = computed[[1]]   # 2019 -> 2020
  r3 = computed[[2]]   # 2020 -> 2021
  # documented semantics per comment: 减少 = 目的地比上期少几项 = prev \ cur
  expect(r2[["减少"]] == 2 && r2[["增加"]] == 0, sprintf(
    "DOC BUG: 2019 {上海,广州,成都} -> 2020 {成都} should be 减少=2 增加=0, code gave 减少=%d 增加=%d (setdiff args swapped vs comment)",
    r2[["减少"]], r2[["增加"]]))
  expect(r3[["减少"]] == 0 && r3[["增加"]] == 1, sprintf(
    "DOC BUG: 2020 {成都} -> 2021 {成都,重庆} should be 减少=0 增加=1, code gave 减少=%d 增加=%d (setdiff args swapped vs comment)",
    r3[["减少"]], r3[["增加"]]))
  TRUE
}),

run_case("B34 paradigms.md closest join (Chinese cols)", {
  df = tibble(值 = c(5, 55, 105))
  lookup = tibble(阈值 = c(0, 50, 100), 档 = c("低", "中", "高"))
  out = df |> left_join(lookup, join_by(closest(值 >= 阈值)))
  stopifnot(nrow(out) == 3, identical(out$档, c("低", "中", "高")))
  TRUE
}),

run_case("B35 paradigms.md double closest join suffix + pmin", {
  df = tibble(有效时长 = c(40, 60), 有效开播日 = c(5, 40))
  lookup = tibble(时长 = c(0, 30, 60), 天数 = c(0, 7, 30),
                  奖励系数 = c(1.0, 1.1, 1.2))
  out = df |>
    left_join(lookup, join_by(closest(有效时长 >= 时长))) |>
    left_join(lookup, join_by(closest(有效开播日 >= 天数))) |>
    mutate(奖励系数 = pmin(奖励系数.x, 奖励系数.y))
  stopifnot(nrow(out) == 2,
            all(c("奖励系数.x", "奖励系数.y") %in% names(out)),
            abs(out$奖励系数[1] - 1.0) < 1e-9,   # min(1.1, 1.0)
            abs(out$奖励系数[2] - 1.2) < 1e-9)   # min(1.2, 1.2)
  TRUE
}),

run_case("B36 paradigms.md capstone full pipeline", {
  set.seed(42); n = 5
  wide = tibble(
    门店 = paste0("S", 1:n),
    区域 = rep(c("华东", "华北"), length.out = n),
    月1 = round(runif(n, 80, 120)), 月2 = round(runif(n, 80, 120)),
    月3 = round(runif(n, 80, 120)), 月4 = round(runif(n, 80, 120)),
    月5 = round(runif(n, 80, 120)), 月6 = round(runif(n, 80, 120))
  ); wide$月3[3] = NA          # 制造缺失月（供组级筛选）

  long = wide |>
    pivot_longer(-c(门店, 区域), names_pattern = "月(\\d)", names_to = "月份", values_to = "销量") |>
    arrange(门店, 月份) |>
    mutate(环比 = 销量 / lag(销量) - 1, .by = 门店)        # 范式3：分组环比

  clean = long |> filter(all(!is.na(销量)), .by = 门店)     # 范式4：S3 出局

  acc = long |> filter(门店 == "S1") |>
    mutate(累计基数 = accumulate(销量[-1], ~ .x * 0.9 + .y, .init = 100))  # 范式6

  final = clean |>
    summarise(总销量 = sum(销量), 均环比 = mean(环比, na.rm = TRUE), .by = 门店) |>
    mutate(排序 = min_rank(-总销量)) |> arrange(排序)        # 范式2：汇总排名

  # 5 stores x 6 months; 环比 NA: 1 per store + S3 month3/month4 = 7
  stopifnot(nrow(long) == 30, sum(is.na(long$环比)) == 7,
            nrow(clean) == 24, !("S3" %in% clean$门店),
            nrow(acc) == 6, acc$累计基数[1] == 100,
            nrow(final) == 4, identical(final$排序, 1:4))
  TRUE
})

)
