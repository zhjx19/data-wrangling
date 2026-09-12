---
name: tidy-data
description: Use when 面对复杂的结构化表格数据处理问题，需要用 R tidyverse（dplyr/tidyr/purrr/slider）解决。适合需要五步法分解任务、重塑整洁数据（pivot_longer/pivot_wider）、管道（|>）、分组计算（.by）、跨列批量（across）、累计迭代（accumulate）、滑窗（slide）、嵌套批量（nest+map）、非等连接（join_by）等场景；也适用于把"Python 列表/循环式思维"改写为管道+数据框思维。不适用于 ggplot2 绘图或非表格数据。
---

# 数据思维：R tidyverse 问题解决框架

> **快速定位范式**：取范式名 → 定位 4 节详述与第 6 节代码范型。

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

## 4. 实战范式库

### 范式 1：列名含信息 → 先宽变长

**何时用**：列名中包含信息（如 `daw_1_`、`month1`、`Q1`），需要按这些信息操作。

**思维轨迹**：列名中的数字/类别是"值"，应该出现在单元格而非列名 → 宽变长后一行一观测 → 操作自然对齐。

**案例**（多列条件计算新列）：
```r
df |> 
  mutate(id = row_number()) |>                              # 先给原始行编号
  pivot_longer(-id, names_pattern = "(.*)_(\\d)", 
               names_to = c(".value", "grp")) |> 
  mutate(adl = if_else(daw == 1, zda, da)) |>   # 现在只需一行
  pivot_wider(id_cols = id, names_from = grp, values_from = c(daw, zda, da, adl))
```

**注意**：`names_pattern` 用正则分组提取列名中的信息，`.value` 表示"这部分保留为列名"。

### 范式 2：分组汇总（每组坍缩为一行）

**何时用**：需要统计每组的总数、均值、最大值等聚合成一行。

```r
df |> summarise(n = n(), mean_x = mean(x, na.rm = TRUE), .by = group)
```

**案例**（月均消费次数/金额/客单价）：
```r
df |> 
  filter(!if_any(1:2, is.na)) |> 
  summarise(总次数 = n_distinct(社保卡号, 销售时间),
            总金额 = sum(实收金额),
            .by = year(销售时间)) |> 
  mutate(客单价 = 总金额 / 总次数)
```

### 范式 3：分组修改（保持原行数，每组内计算）

**何时用**：需要按组计算新列，但保持每行不变。典型场景：分组环比、分组排名、分组标准化。

> **注意（顺序前提）**：`lag()` 依赖行内顺序——使用前先 `arrange(分组列, 时间列)` 保证时间升序，否则环比/同比会静默算错；分组内首行的 `lag()` 结果为 `NA` 属预期，无需处理。

```r
df |> mutate(新列 = 计算式, .by = 分组列)
```

**案例**（计算同比、环比、定基比）：
```r
df |> 
  mutate(环比 = (销售额 / lag(销售额) - 1),
         同比 = (销售额 / lag(销售额, 12) - 1),
         定基比 = (销售额 / first(销售额[日期 == baseDate]) - 1),
         .by = 地区)
```

### 范式 4：分组筛选（选每组中的子行或整组）

**何时用**：需要根据组内条件过滤行。

```r
df |> filter(条件, .by = 分组列)      # 行级筛选：每组内选行
df |> filter(all(条件), .by = 分组列)  # 组级筛选：条件对整组为TRUE才保留
```

**案例**（分组筛选行 vs 整组筛选行）：
```r
# 删除每组中 x 为 NA 的行（行级）
df |> filter(!is.na(x), .by = g)

# 只要该组包含 NA 就整组删除（组级）
df |> filter(all(!is.na(x)), .by = g)

# 缺失比例 >= 60% 的组才删除
df |> filter(mean(is.na(x)) < 0.6, .by = g)
```

**关键理解**：`all()` 把每组逻辑向量坍缩为一个逻辑值，实现**组级**筛选——条件对整组为真才保留；不带 `all()` 的 `filter(条件, .by = g)` 是**行级**筛选，每个逻辑值作用于其所在行。

**多列行级筛选（`if_all` / `if_any`）**：跨多列构造行级条件用 `if_all()` / `if_any()`（dplyr ≥1.0.4，不是禁用的 scoped 变体）：

```r
df |> filter(if_all(c(x, y), ~ !is.na(.x)), .by = g)  # x、y 都非缺失才保留该行
df |> filter(if_any(1:2, is.na), .by = g)             # 前两列任一缺失就删该行
```

`if_all()` 要求所选列**全部**满足条件；`if_any()` 任一列满足即可——两者是**行级**多列筛选，区别于上面 `all()` 的**组级**筛选。

> **陷阱（取反的 `if_any` 静默丢行）**：`if_any` 的 NA 会传播——所选列存在 NA 且其余列不匹配时条件为 `NA`，`filter()` 把整行**当 FALSE 静默丢弃**。取反检测（如"剔除汇总行"）必须先 `coalesce(x, "")` 兜底：
> `filter(!if_any(where(is.character), \(x) str_detect(str_squish(coalesce(x, "")), "^总计$")))`
> （回归实证：`scripts/verify_examples.R` 第 9 例——不带 coalesce 时 region 为 NA 的正常数据行被误删。）

### 范式 5：nest + map（法宝模式）—— 分组后每组操作产生不同行数

**何时用**：分组后每组的操作不能简单地用 `.by` 完成（例如分组连接、分组建模、分组读文件）。

> **优先试试 `reframe()`（dplyr ≥1.1）**：若每组只是"返回若干行标量结果"（分位数、区间、衍生标签），可直接用 `reframe(x, .by = g)`，无需 nest + map 的繁琐。只有每组要对**子数据框本身做复杂变换**（连接、建模、读文件）才需要下面的 nest + map。

```r
df |> 
  nest(.by = 分组列) |>              # 每个分组占一行，data 列是子数据框
  mutate(data = map(data, 函数)) |>  # 对每个子数据框做操作
  unnest(data)                        # 展开回到原结构
```

**案例 1**（分组数据连接——每个日期下右连接全部员工）：
```r
df1 |> 
  nest(.by = Date) |> 
  mutate(data = map(data, ~ right_join(.x, df2, by = "ID"))) |> 
  unnest(data) |> 
  replace_na(list(Salary = 0))
```
> 为什么不能直接 `group_by(Date) |> right_join(...)`？因为直接分组连接，未出现 ID 只会出现 1 次（不是每组 1 次）。用 nest 把每组"隔离"后再分别连接。

**案例 2**（分组批量读取文件并合并）：
```r
tibble(files = list.files("data/", full.names = TRUE)) |> 
  mutate(grp = str_extract(files, ".(?=\\d)")) |> 
  nest(.by = grp, .key = "files") |> 
  mutate(data = map(files, ~ map_dfr(.x$files, read_csv)))
```

### 范式 6：累计迭代（accumulate）

**何时用**：需要"用上次结果计算这次结果"的累计运算——累计和、永续盘存、递推公式。

```r
# accumulate(序列, 二元函数, .init = 启动值)
# .x = 上次累计结果或启动值, .y = 序列当前值
# ⚠ 带 .init 时返回长度 = 序列长度 + 1（首元素是启动值）；放进 mutate 须用 序列[-1]，见下注意

df |> mutate(累计结果 = accumulate(序列[-1], ~ .x * .y / 100, .init = 启动值))
```

> **注意（长度对齐）**：带 `.init` 的 `accumulate` 返回长度 = 序列长度 + 1（首元素为启动值），直接放进 `mutate` 会行数错位。统一写法为 `accumulate(序列[-1], ..., .init = 首值)`——去掉序列首元素后输出长度恰好等于行数（首行即启动值）。范式 6 通用形式、下方案例与 6.9 范型一致采用此写法。

**案例**（永续盘存法计算资本存量，K_t = K_{t-1}(1-δ) + I_t）：
```r
df |> 
  mutate(基期指数 = accumulate(价格指数[-1], ~ .x * .y / 100, .init = 100),
         资本存量 = accumulate(固定资产投资[-1], ~ .x * (1 - 0.05) + .y, .init = 基期资本))
```

### 范式 7：滑窗迭代（slide）

**何时用**：需要"窗口滚动计算"——滚动均值、相邻比较、滑动窗口内操作。

```r
library(slider)
# slide(序列, 函数, .before = 1, .complete = TRUE)
```

**案例**（分组滚动对目的地变化计数）：
```r
df |> nest(.by = c(from, year)) |> 
  mutate(result = slide(data, \(x) {
      if(length(x) < 2) return(NA)
      c(减少 = setdiff(x[[2]]$目的地, x[[1]]$目的地) |> length(),
        增加 = setdiff(x[[1]]$目的地, x[[2]]$目的地) |> length())
    }, .before = 1, .complete = TRUE))
```
> 注意：`slide(..., .complete = TRUE)` 在窗口不完整时返回 NULL，需自行处理边界情形（如 `length(x) < 2` 返回 `NA`）；若希望始终返回向量，改用 `slide_dbl`。

> **slide vs slide_dbl 口径**：`slide()` 每个窗口可返回**任意长度**（可多元素，如上面"减少/增加"两值），窗口不完整时按 `.complete` 返回部分窗口或 NULL；`slide_dbl()` 强制每个窗口返回**单个数值**（适合 `mutate` 标量新列，如滚动均值），不完整窗口 `.complete=TRUE` 时返回 `NA`。单值用 `slide_dbl`（见 6.10），多值用 `slide`。

### 范式 8：非等连接

**何时用**：连接条件不是 `=`，而是 `>=`、`closest` 等。

```r
df |> left_join(lookup, join_by(closest(值 >= 阈值)))
```

**案例**（计算主播奖励系数——有效时长/开播日 ≥ 查找表中各档最低线，选最接近档）：
```r
df |> 
  left_join(lookup, join_by(closest(有效时长 >= 时长))) |> 
  left_join(lookup, join_by(closest(有效开播日 >= 天数))) |> 
  mutate(奖励系数 = pmin(奖励系数.x, 奖励系数.y))
```

> **非等连接三形态**（dplyr ≥1.1）：`join_by(值 >= 阈值)` 按不等式连接（可多行匹配，全部满足档都会连上）；`join_by(closest(值 >= 阈值))` 每个左行只取最接近的一档；`join_by(within(区间))` / `join_by(overlap(区间))` 处理区间包含 / 重叠。选型：只取最近一档 → `closest`；要列出全部满足档 → 直接用 `>=`；区间匹配 → `within` / `overlap`。

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

> 本节与 §4 范式详述对应：这里只给最短可复制写法，`§4` 有"何时用 / 思维轨迹 / 案例 / 注意"的完整逻辑。范式代码改动后，跑 `scripts/verify_examples.R` 一键回归（8 范式 + §12 综合案例，全 PASS 才收工）。

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
| 取反 `filter(!if_any(...))` | `if_any` 的 NA 传播：含 NA 行整行按 FALSE **静默丢弃** | 检测条件内先 `coalesce(x, "")` 兜底（见范式 4 陷阱） |

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

## 10. 自检清单

- [ ] 数据是否已重塑为整洁形式？（列名含信息？用 `pivot_longer`）
- [ ] 复杂任务是否已分解为基本操作序列？
- [ ] 每个 `mutate`/`filter`/`summarise` 只做一件事？
- [ ] 每组返回若干标量行用 `reframe`；需对子数据框变换才用 `nest + map`？
- [ ] 需要累计迭代时用 `accumulate`，滑窗用 `slide`？
- [ ] 多表连接前检查了连接关系？（1:1 / 1:N / N:1 / N:N）
- [ ] 管道串联后结果符合预期形状？
- [ ] 代码遵守 `=` / `|>` / `\(x)` / `.by` 规范？
- [ ] 代码模板改动后运行 `scripts/verify_examples.R`，8 范式 + §12 综合案例全 PASS？

## 11. 思维总结

> 拿到任何数据问题，先问三个问题：
> 1. **数据整洁吗？**（不整洁 → 先 pivot_longer）
> 2. **需要分组吗？**（分组 → `.by`；返回若干标量行 → `reframe`；子数据框变换 → nest+map）
> 3. **需要特殊的迭代方式吗？**（累计 → accumulate；滑动 → slide）
>
> 剩下的就是：**每一步只做一件事，用管道串起来。**

## 12. 综合案例（多范式串联）

> 一个真实感的完整例子，把 范式1→3→4→6→2 串起来；完整可运行脚本见 `scripts/verify_examples.R`（8 范式 + 本案例一键回归，R 4.6.1 实跑通过）。

**问题**：门店销售宽表（`门店/区域/月1..月6` 每月销量一列），要 (a) 算每家门店每月环比；(b) 删除任一月份缺失的整店；(c) 用累计法算 S1 的"累计基数"（基数_t = 基数_{t-1}×0.9 + 销量_t，基数_1 = 100）；(d) 对剩余门店按总销量排名。

```r
library(tidyverse); library(slider)
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

clean = long |> filter(all(!is.na(销量)), .by = 门店)     # 范式4：删含缺失整组（S3 出局）

acc = long |> filter(门店 == "S1") |>
  mutate(累计基数 = accumulate(销量[-1], ~ .x * 0.9 + .y, .init = 100))  # 范式6

clean |>
  summarise(总销量 = sum(销量), 均环比 = mean(环比, na.rm = TRUE), .by = 门店) |>
  mutate(排序 = min_rank(-总销量)) |> arrange(排序)        # 范式2：汇总排名
```

**结果**（R 4.6.1 实跑）：S3 因含缺失被整组删除（剩 S1/S2/S4/S5）；S1 累计基数首行 = 100（accumulate 长度对齐正确）；排名 S1>S2>S4>S5。完整输出以 `scripts/verify_examples.R` 运行结果为准。
