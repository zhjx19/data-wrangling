---
name: tidy-data
description: >-
  Use when 面对复杂的结构化表格数据处理问题，需要用 R tidyverse（dplyr/tidyr/purrr/slider）解决。
  适合需要五步法分解任务、重塑整洁数据（pivot_longer/pivot_wider）、管道（|>）、分组计算（.by）、
  跨列批量（across）、累计迭代（accumulate）、滑窗（slide）、嵌套批量（nest+map）、非等连接（join_by）
  等场景；也适用于把"Python 列表/循环式思维"改写为管道+数据框思维。不适用于 ggplot2 绘图或非表格数据。
  Triggers: 数据思维/tidyverse 怎么写/宽表转长表/长表转宽表/分组计算/每组汇总/环比同比/累计迭代/滑窗滚动/非等连接/嵌套批量/不要用 for 循环.
related-skills:
  - data-cleaning
compatibility: claude-code, zcode, opencode, codex
---

# 数据思维：R tidyverse 问题解决框架

> **快速定位范式**：取范式名 → 完整详述见 [references/paradigms.md](references/paradigms.md)，最短可复制写法在第 6 节速查。

| 问题信号 | 范式 | 核心函数 |
|---|---|---|
| 列名含信息 | 1 先宽变长 | `pivot_longer` / `pivot_wider` |
| 每组坍缩一行 | 2 分组汇总 | `summarise(.by=)` |
| 每组内改列、行数不变 | 3 分组修改 | `mutate(.by=)` |
| 选组内行 / 整组 | 4 分组筛选 | `filter(.by=)` / `filter(all(), .by=)` |
| 每组行数变化 | 5 嵌套批量 | `nest(.by=)` + `map` + `unnest` |
| 用上次算这次 | 6 累计迭代 | `accumulate` |
| 窗口滚动 | 7 滑窗迭代 | `slide_dbl` |
| 连接非等号 | 8 非等连接 | `join_by(closest(>=))` |

## 1. 定位与边界

本技能固化「数据思维」框架——**教拿到数据问题后如何思考**；思考之后，仍要落到能解决实际问题的 R 代码，两者一体、不可偏废。

核心命题：> **多数数据问题都可以用同一套数据思维解决：重塑为整洁数据 → 复杂任务分解为多步基本操作 → 用 tidyverse 代码实现。**

- **适用**：任何结构化表格数据的分析、处理、转换、建模问题。
- **不适用**：ggplot2 图形语法（不在本技能范围）、非表格数据、需特定领域深度知识的问题。
- **与数据清洗的关系**：数据清洗专注"脏数据→干净数据"的审计与清洗流程；本技能是更高层的通用思维框架，"清洗"只是其中一步。
- **与 ml-mlr3 的分工**：本技能的 nest+map 分组建模是轻量探索性建模；若要正式的预测建模流程（mlr3verse 重抽样、调优、基准比较），转用 `ml-mlr3` 技能。

### 1.1 环境要求

本技能使用现代 tidyverse 语法，运行前确认依赖与版本，否则代码会直接报错：

| 语法 | 来源 | 最低版本 |
|---|---|---|
| `.by = `（分组） | dplyr | 1.1.0 |
| `across()` / `if_any()` | dplyr | 1.0.4 |
| `reframe(.by = )` | dplyr | 1.1.0 |
| `nest(.by = )` | tidyr | 1.3.0 |
| `pivot_longer/wider` | tidyr | 1.0.0 |
| `accumulate()` | purrr | — |
| `slide()` / `slide_dbl()` | slider | — |
| `join_by(closest())` | dplyr | 1.1.0 |

首次使用可用 `install.packages(c("dplyr", "tidyr", "purrr", "slider"))` 安装。

## 2. 核心理念

### 2.1 函数式编程：操作与数据分离

```text
操作写成函数 → 再将函数作用到数据
    ├── 批量地作用：循环迭代（map / apply 家族）
    ├── 依次地作用：管道（|>）
    ├── 在数据框里面作用：数据思维（across 等）
    └── 在数据框列表列里循环迭代：批量建模/计算/可视化
```

核心思想：**把"做什么"写成一个函数，然后决定"对谁做、怎么做"。**

### 2.2 数据思维 = 数据框思维

> 用数据框容器，在数据框的逻辑下解决问题。不用列表推导式、不用集合、不用 zip/map——数据框原生操作就能完成。

### 2.3 分组思维三合一

对每组（子数据框）做操作，直接写"分组 + 操作"：

| 模式 | 语法 | 含义 |
|---|---|---|
| **分组汇总** | `summarise(... , .by = g)` | 每组坍缩为一行 |
| **分组修改** | `mutate(... , .by = g)` | 每组内逐行计算，保持原行数 |
| **分组筛选** | `filter(... , .by = g)` | 每组内选子行 |

遇到"分组 + 数据连接"这种不能用 `.by` 直接搞定的，用法宝：**nest + map + unnest**。

### 2.4 嵌套批量（法宝模式）

当"分组后每组的操作产生不同行数"时——例如分组连接、分组建模、分组读取文件——就用这个模式：

```
nest(.by = 分组列) → mutate(data = map(data, 对每组做的操作)) → unnest()
```

## 3. 五步数据思维法

> **拿到数据问题，先给形状预判，再写代码**：说明输出几列几行、分组粒度、每个操作的作用，然后才用管道实现。跳过分析直接堆代码是常见失败点。

| 步骤 | 关键动作 | 核心操作 |
|---|---|---|
| ① 理解目标 | 输入→输出形状？需要什么结构？ | 明确输出列、行数、分组粒度 |
| ② 重塑整洁 | 数据整洁吗？列名含信息吗？ | `pivot_longer` / `pivot_wider` / `separate` / `join` |
| ③ 操作分解 | 复杂任务 → 基本操作序列 | `filter` → `mutate` → `summarise` → `arrange` → `select` |
| ④ 函数式批量化 | 需要分组？需要批量？ | `.by` / `across` / `nest + map` / `accumulate` / `slide` |
| ⑤ 管道验证 | 串联所有步骤，验证结果 | `|>` + 检查 |

**核心口诀**：
- **数据不整洁，先变整洁！**（列名含有信息时，第一步永远是 `pivot_longer`）
- **复杂问题 = 基本操作的序列**（每一个 `filter`/`mutate`/`summarise` 只做一件事）
- **分组操作首选 `.by`，不行就用 `nest + map`**

## 4. 实战范式库（详述见 [references/paradigms.md](references/paradigms.md)）

| # | 范式 | 何时用 | 通用形式 |
|---|---|---|---|
| 1 | 先宽变长 | 列名含信息（`daw_1_`、`month1`） | `pivot_longer(-id, names_pattern, names_to = c(".value", "grp"))` |
| 2 | 分组汇总 | 每组坍缩为一行 | `summarise(..., .by = group)` |
| 3 | 分组修改 | 组内改列、行数不变（环比/排名/标准化；**`lag` 前先 `arrange`**） | `mutate(新列 = 计算式, .by = 分组列)` |
| 4 | 分组筛选 | 选组内行 / 整组 | `filter(条件, .by = g)`；组级 `filter(all(条件), .by = g)`；多列行级 `if_all`/`if_any`（**取反 `if_any` 有 NA 静默丢行陷阱，见反模式表**） |
| 5 | 嵌套批量 | 每组行数变化（分组连接/建模/读文件）；仅返回标量行用 `reframe(.by=)` | `nest(.by = g) \|> mutate(data = map(data, f)) \|> unnest(data)` |
| 6 | 累计迭代 | 用上次算这次（永续盘存/递推） | `accumulate(序列[-1], ~ .x · .y, .init = 首值)` |
| 7 | 滑窗迭代 | 窗口滚动 | 单值 `slide_dbl(x, mean, .before = 2, .complete = TRUE)`；多值 `slide()` |
| 8 | 非等连接 | 条件是 `>=`/`closest`/区间 | `left_join(lookup, join_by(closest(值 >= 阈值)))` |

> 每个范式的"何时用 / 思维轨迹 / 案例 / 注意"完整逻辑与多范式串联综合案例，见 [references/paradigms.md](references/paradigms.md)。

## 5. 决策树

拿到一个数据问题，依次问：

```
1. 数据整洁吗？
   ├─ 列名含信息（如 month_1, Q1, daw_1_） → 范式 1：pivot_longer
   ├─ 需要拆分列（如 "01-A001,02"） → separate + stringr
   └─ 需要多表合并？ → left_join / right_join / bind_rows

2. 需要分组吗？
   ├─ 每组坍缩为一行 → 范式 2：summarise(.by=)
   ├─ 每组内修改列 → 范式 3：mutate(.by=)
   ├─ 行级筛选 → 范式 4：filter(.by=)
   ├─ 组级筛选（含某值则整组删） → 范式 4：filter(all(), .by=)
   ├─ 每组返回标量若干行 → reframe(.by=)（轻量）
   └─ 每组对子数据框复杂变换 → 范式 5：nest + map

3. 需要迭代/窗口吗？
   ├─ 累计迭代（用上次结果算这次） → 范式 6：accumulate
   └─ 滑动窗口（相邻比较） → 范式 7：slide

4. 连接条件不是等号？
   └─ 范式 8：非等连接 join_by(closest())

5. 需要跨多列做同一操作？
   ├─ 整洁数据：across(c(col1, col2), 函数)
   └─ 不整洁数据：先 pivot_longer → 操作 → pivot_wider

6. 需要数据清洗？
   └─ 走数据清洗流程（缺失/异常/去重/审计）
```

## 6. 代码范型速查

> 本节是最短可复制写法；每个范式的"何时用 / 思维轨迹 / 案例 / 注意"完整逻辑见 [references/paradigms.md](references/paradigms.md)。范式代码改动后，跑 `scripts/verify_examples.R`（9 例）与 `scripts/verify_prompts.R`（3 题）一键回归，全 PASS 才收工。

### 6.1 分组汇总
```r
df |> summarise(n = n(), mean_x = mean(x, na.rm = TRUE), .by = group)
```

### 6.2 分组修改
```r
df |> mutate(pct = (x - lag(x)) / lag(x) * 100, .by = group)
```

### 6.3 分组筛选（行级）
```r
df |> filter(x == max(x), .by = group)
```

### 6.4 整组筛选（组级）
```r
df |> filter(all(x > 0), .by = group)     # 全为正才保留整组
df |> filter(mean(is.na(x)) < 0.5, .by = group)  # 缺失率 < 50%
```

### 6.5 跨列批量化（整洁数据）
```r
df |> mutate(across(where(is.numeric), \(x) scale(x)[,1]))
df |> summarise(across(starts_with("sales_"), \(x) mean(x, na.rm = TRUE)))
```

### 6.6 跨列批量化（不整洁数据 → 先长后宽）
```r
df |> 
  pivot_longer(-id, names_to = "var", values_to = "val") |> 
  mutate(val = 函数(val), .by = c(id, var)) |> 
  pivot_wider(names_from = var, values_from = val)
```

### 6.7 重塑（宽 ↔ 长）
```r
# 宽 → 长（列名信息进单元格）
df |> pivot_longer(-固定列, names_to = "k", values_to = "v")

# 长 → 宽（值变列名）
df |> pivot_wider(names_from = k, values_from = v, names_prefix = "pre_")

# 含多个变量的列名（用正则拆）
df |> pivot_longer(-id, names_pattern = "(.*)_(\\d+)", names_to = c(".value", "num"))
```

### 6.8 嵌套批量（nest + map）
```r
df |> 
  nest(.by = group) |> 
  mutate(data = map(data, ~ 对子数据框的操作(.x))) |> 
  unnest(data)

# 轻量替代：每组只返回若干标量行，直接用 reframe()
df |> reframe(qs = quantile(x, c(0.25, 0.75)), .by = group)
```

### 6.9 累计迭代
```r
df |> mutate(cum = accumulate(x[-1], ~ .x + .y, .init = first(x)))
```

### 6.10 滑窗迭代
```r
library(slider)
df |> mutate(rolling_mean = slide_dbl(x, mean, .before = 2, .complete = TRUE))
```

### 6.11 非等连接
```r
df |> left_join(lookup, join_by(closest(value >= threshold)))
```

## 7. 反模式（绝对要避免的）

| 反模式 | 为什么错 | 正确做法 |
|---|---|---|
| for 循环逐行操作 | 破坏向量化，慢、乱、不可读 | `mutate`/`summarise` |
| 盲 join 不检查连接关系 | 可能 N:N 爆炸行数 | 先 distinct 检查键唯一性 |
| 忘记 ungroup | 后续操作在分组状态下执行 | `.by` 单次分组（无副作用），或 `ungroup()` |
| `ifelse()` 嵌套 | 难以维护 | `case_when()` 或因子重编码 |
| 用 `%>%` 而非 `\|>` | 不统一 | 统一用原生管道 `\|>` |
| `gather/spread` | 已退役 | `pivot_longer/pivot_wider` |
| 不整洁数据直接操作 | 列名中含信息时操作极其痛苦 | 先 `pivot_longer` |
| 用 Python 式列表/集合思维 | 数据框原生操作更简洁 | `distinct`/`count`/`filter` |
| `across` 搭配 `if_any` 混淆 | `if_any` 是筛选行，`across` 是修改列 | 分清场景再选函数 |
| 管道内混合 `\|>` 和 `%>%` | 不一致 | 统一 `\|>` |
| 取反 `filter(!if_any(...))` | `if_any` 的 NA 传播：含 NA 行整行按 FALSE **静默丢弃** | 检测条件内先 `coalesce(x, "")` 兜底（详述见 references/paradigms.md 范式 4） |

## 8. 常见问题与错误思维（破除外来习惯）

### 8.1 "我想遍历这一列，对每个值……"
→ 错！**向量化思维**：操作是同时作用于整列的，不需要"遍历"。直接用 `mutate`/`summarise`。

### 8.2 "我要写个 for 循环，把每行的 XX 算出来……"
→ 错！这违背了数据框操作的**整体考量**原则。数据框的列向量操作自动作用于每一行。

### 8.3 "这个不重复值问题用 set/map/zip……"
→ 错！`distinct()` 就是不重复，`count()` 就是计数。数据框自带这些操作，不需要引入外部数据结构。

### 8.4 "前面结果存变量，下一步再用变量……"
→ 错！**管道思维**：所有步骤写在管道里，前一步结果自动流向下一步，不需要中间变量。

### 8.5 "这是经典算法，我要一步一步模拟……"
→ 不一定！很多"经典算法"本质是数据操作。比如永续盘存法的递推公式 → `accumulate`。先用数据思维审视，再看是否需要特殊处理。

### 8.6 "直接分组 + 连接就行了吧……"
→ **先想每组的输出是几行**。如果每组输出行数与原组不同（如连接引入新行、建模输出标量），就不能直接用 `.by`。返回若干标量行用 `reframe(.by=)`；若需对子数据框做连接/建模/读文件等复杂变换，则走 **nest + map + unnest**。

## 9. R 代码铁律

严格遵守现代 R 风格：

- 赋值用 `=`；管道用 `|>`；匿名函数用 `\(x)`；分组用 `.by`
- 禁用：`ifelse()`、`merge()`、`gather()/spread()`、`*_at()/_if()/_all()`（dplyr 旧版作用域变体，如 `summarise_all`、`mutate_if`）、`%>%`

> 基础函数 `all()` 与 `if_all()` / `if_any()` 不受上述禁用影响——多列行级筛选就用 `filter(if_all()/if_any(), .by)`（见范式 4）。

> 铁律与 `data-cleaning` 技能的"R 风格铁律"同源（`=`、`|>`、`\(x)`、`.by`、禁 `ifelse`/`merge`/`%>%`/旧 scoped 变体）。两处任一改动，必须双向同步；本节的 `all()`/`if_all()`/`if_any()` 澄清与范式 4 的 NA 传播陷阱为本 skill 特有。

## 10. 自检清单

- [ ] 交付前是否对照第①步的形状预判验证了输出？（几列几行、分组粒度）
- [ ] 数据是否已重塑为整洁形式？（列名含信息？用 `pivot_longer`）
- [ ] 复杂任务是否已分解为基本操作序列？
- [ ] 每个 `mutate`/`filter`/`summarise` 只做一件事？
- [ ] 每组返回若干标量行用 `reframe`；需对子数据框变换才用 `nest + map`？
- [ ] 需要累计迭代时用 `accumulate`，滑窗用 `slide`？
- [ ] 多表连接前检查了连接关系？（1:1 / 1:N / N:1 / N:N）
- [ ] 管道串联后结果符合预期形状？
- [ ] 代码遵守 `=` / `|>` / `\(x)` / `.by` 规范？
- [ ] 代码模板改动后运行 `scripts/verify_examples.R`（9 例）与 `scripts/verify_prompts.R`（3 题），全 PASS 才收工？

## 11. 思维总结

> 拿到任何数据问题，先问三个问题：
> 1. **数据整洁吗？**（不整洁 → 先 pivot_longer）
> 2. **需要分组吗？**（分组 → `.by`；返回若干标量行 → `reframe`；子数据框变换 → nest+map）
> 3. **需要特殊的迭代方式吗？**（累计 → accumulate；滑动 → slide）
>
> 剩下的就是：**每一步只做一件事，用管道串起来。**

## 12. 综合案例与范式详述

8 范式的"何时用 / 思维轨迹 / 案例 / 注意"完整逻辑与多范式串联综合案例（范式1→3→4→6→2），见 [references/paradigms.md](references/paradigms.md)。可运行回归：`scripts/verify_examples.R`（9 例）与 `scripts/verify_prompts.R`（3 题 7 检查）。
