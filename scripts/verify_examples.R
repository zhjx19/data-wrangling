#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-
# verify_examples.R —— tidy-data skill 代码模板一键回归脚本
#
# 逐项实跑 SKILL.md §4 的 8 个范式代码模板 + §附录的综合案例，
# 证明框架代码在当前 tidyverse 版本下可运行。改动 SKILL.md 代码后跑一遍本脚本。
#
# 本脚本自身遵守 R 铁律：= 赋值、|> 管道、\(x) 匿名函数、.by 分组汇总。
#
# 用法（skill 目录下）：
#   Rscript scripts/verify_examples.R
# 或任意目录：
#   Rscript <skill-dir>/scripts/verify_examples.R
#
# 退出码：0 = 全部 PASS；1 = 任一 FAIL。
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
  ## ---- 范式1：列名含信息 → 宽变长（.value + names_pattern）----
  run_case("范式1 宽变长(.value)", {
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

  ## ---- 范式2：分组汇总 ----
  run_case("范式2 分组汇总", {
    df = tibble(group = c("A", "A", "B"), x = c(1, 3, 5))
    out = df |> summarise(n = n(), mean_x = mean(x, na.rm = TRUE), .by = group)
    stopifnot(nrow(out) == 2, out$n[1] == 2, out$mean_x[2] == 5)
    out
  }),

  ## ---- 范式3：分组修改（环比/同比，先 arrange 保证 lag 顺序）----
  run_case("范式3 分组环比/同比", {
    df = expand.grid(地区 = c("A", "B"), 月份 = 1:12) |>
      mutate(销售额 = round(runif(24, 50, 150), 0))
    out = df |>
      arrange(地区, 月份) |>
      mutate(
        环比 = (销售额 / lag(销售额) - 1),
        同比 = (销售额 / lag(销售额, 12) - 1),
        .by = 地区
      )
    stopifnot(nrow(out) == 24, is.na(out$环比[1]), is.na(out$同比[13]))
    out
  }),

  ## ---- 范式4：组级筛选 filter(all(), .by) + 多列行级 if_all ----
  run_case("范式4 组级筛选 + if_all", {
    df = tibble(
      g = c("A", "A", "A", "B", "B", "B"),
      x = c(1, 2, 3, 1, NA, 3), y = c(1, 1, 1, 1, 1, 1)
    )
    grp = df |> filter(all(!is.na(x)), .by = g)                 # B 组含 NA → 整组删
    rowok = df |> filter(if_all(c(x, y), \(v) !is.na(v)), .by = g)  # 行级多列
    stopifnot(all(grp$g == "A"), !any(is.na(rowok$x)))
    TRUE
  }),

  ## ---- 范式5：nest + map 分组连接 ----
  run_case("范式5 nest+map 分组连接", {
    df1 = tibble(Date = c("2026-01-01", "2026-01-01", "2026-01-02"),
                 ID = c(1, 2, 3), v = c(1, 2, 3))
    df2 = tibble(ID = 1:3, Salary = c(10, 20, 30))
    out = df1 |>
      nest(.by = Date) |>
      mutate(data = map(data, \(d) right_join(d, df2, by = "ID"))) |>
      unnest(data) |>
      replace_na(list(Salary = 0))
    stopifnot(nrow(out) == 6)   # 每个日期 3 员工
    out
  }),

  ## ---- 范式6：accumulate 长度对齐（序列[-1] + .init）----
  run_case("范式6 accumulate 长度对齐", {
    df = tibble(价格指数 = c(105, 102, 108, 101))
    out = df |> mutate(基期指数 = accumulate(价格指数[-1], \(x, y) x * y / 100, .init = 100))
    stopifnot(nrow(out) == 4, out$基期指数[1] == 100, out$基期指数[2] == 102)
    out
  }),

  ## ---- 范式7：slide 滑窗（slide_dbl 单值 + .complete=TRUE）----
  run_case("范式7 slide_dbl .complete=TRUE", {
    df = tibble(x = 1:10)
    out = df |> mutate(rolling = slide_dbl(x, mean, .before = 2, .complete = TRUE))
    stopifnot(nrow(out) == 10, is.na(out$rolling[1]), out$rolling[3] == 2)
    out
  }),

  ## ---- 范式8：非等连接 join_by(closest) ----
  run_case("范式8 join_by(closest)", {
    df = tibble(有效时长 = c(30, 90, 200))
    lookup = tibble(时长 = c(0, 50, 100, 300), 系数 = c(1, 2, 3, 4))
    out = df |> left_join(lookup, join_by(closest(有效时长 >= 时长)))
    stopifnot(nrow(out) == 3, all(out$系数 == c(1, 2, 3)))
    out
  })
)

## ---- 综合案例：门店销售分析（多范式串联）----
cat("\n=== 综合案例：门店销售分析（宽表→环比→组级筛选→累计→汇总） ===\n")
set.seed(42)
n = 5
wide = tibble(
  门店 = paste0("S", 1:n),
  区域 = rep(c("华东", "华北"), length.out = n),
  月1 = round(runif(n, 80, 120)), 月2 = round(runif(n, 80, 120)),
  月3 = round(runif(n, 80, 120)), 月4 = round(runif(n, 80, 120)),
  月5 = round(runif(n, 80, 120)), 月6 = round(runif(n, 80, 120))
)
wide$月3[3] = NA  # 制造一家门店某月缺失（用于组级筛选）

# ① 范式1：列名含信息 → 宽变长
long = wide |>
  pivot_longer(-c(门店, 区域), names_pattern = "月(\\d)", names_to = "月份", values_to = "销量")
# ② 范式3：分组环比（先 arrange 保证顺序）
long = long |>
  arrange(门店, 月份) |>
  mutate(环比 = 销量 / lag(销量) - 1, .by = 门店)
# ③ 范式4：组级筛选——删掉有缺失月的整组
clean = long |> filter(all(!is.na(销量)), .by = 门店)
stopifnot(setequal(clean$门店, c("S1", "S2", "S4", "S5")), nrow(clean) == 24)
# ④ 范式6：accumulate 累计基数
acc = long |>
  filter(门店 == "S1") |>
  mutate(累计基数 = accumulate(销量[-1], \(x, y) x * 0.9 + y, .init = 100))
stopifnot(nrow(acc) == 6, acc$累计基数[1] == 100, acc$累计基数[2] == round(100 * 0.9 + acc$销量[2]))
# ⑤ 范式2：分组汇总排名
summ = clean |>
  summarise(总销量 = sum(销量, na.rm = TRUE), 均环比 = mean(环比, na.rm = TRUE), .by = 门店) |>
  mutate(排序 = min_rank(-总销量)) |>
  arrange(排序)
stopifnot(nrow(summ) == 4, summ$排序[1] == 1)
print(summ)

## ---- 汇总 ----
fails = names(results)[results != "PASS"]
cat(sprintf("\n=== 汇总：%d/%d PASS ===\n", sum(results == "PASS"), length(results)))
if (length(fails) > 0) {
  for (f in fails) cat("FAIL:", f, "->", results[[f]], "\n")
  quit(status = 1)
}
quit(status = 0)
