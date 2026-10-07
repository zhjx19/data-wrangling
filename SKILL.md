---
name: data-wrangling
description: >-
  R tidyverse 数据问题「定位器」：拿到表格数据问题，先定位该用哪个范式、再动手写码，而不是查函数手册。
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
- **不适用**：ggplot2 绘图语法细节（绘图本身不在本技能范围；但"每列/每组各画一张图"的**批量组织**属于总纲(4)与范式 5 的管辖）、非表格数据、需特定领域深度知识的问题。
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
| `separate_wider_*` | tidyr | 1.3.0 |
| `slice_max(..., by = )` | dplyr | 1.1.0 |
| `pivot_longer/wider` | tidyr | 1.0.0 |
| `accumulate()` | purrr | — |
| `slide()` / `slide_dbl()` | slider | — |
| `join_by(closest())` | dplyr | 1.1.0 |

首次使用可用 `install.packages(c("dplyr", "tidyr", "purrr", "slider"))` 安装。

## 2. 总纲：数据思维 2.0（核心指导思想）

> 总指导思想是一张思维导图（`assets/data-thinking-2.0.png`）：

```text
数据思维
├── 操作数据框思维 ←── 向量化 + 函数式（自定义函数 / 泛函式循环迭代）──→ 批量建模/计算/可视化
├── 数据分解思维 ────→ 分组操作 + 同时操作多列 ────────────────→ 批量建模/计算/可视化
└── 操作分解思维 ←─── 管道（复杂操作 = 基本操作的序列）
```

**（1）把向量化编程思维和函数式编程思维，纳入到数据框或更高级的数据结构中。**
向量化编程能同时操作一个向量的数据，把它转变成为：在数据框中操作一列的数据、同时操作数据框的多列，甚至分别操作数据框每个分组的多列；函数式编程则转变成为：把想实现的操作写成自定义函数（或使用现成函数），再依次应用到数据框的多个列上，以修改列或进行汇总。

**（2）将复杂数据操作分解为若干基本数据操作。**
复杂数据操作都可以分解为若干简单的基本数据操作：数据连接、数据重塑（长宽变换/拆分合并列）、排序行、选择列、修改列、分组汇总等。一旦完成问题的梳理和分解，又熟悉每个基本的数据操作，用"管道流"依次对数据做操作即可。

**（3）接受数据分解的操作思维——你只需关心"分别操作"的部分。**
比如想对数据框分组、分别对每组数据做操作，整体来看是不容易想透的复杂事情，实际上只需通过 `.by` 参数分组，然后把对**一组**数据要做的操作实现出来；再比如用 `across()` 同时操作多列，实际上只需把对**一列**数据要做的操作实现出来。这些函数会帮你"**分解 + 分别操作 + 合并结果**"，你只需要关心"分别操作"的部分，它就变成一件简单的事情。

**（4）汇聚点：批量建模/计算/可视化。**
实际分析中，任务往往不止是"建一个模型、算一个指标、画一张图"，而是"每个分组各建一个模型、算一个指标、画一张图"。此时，前述思维可以自然地推向更高层级：先按分组变量将数据框打包成带有列表列的嵌套数据框；再针对**单份**数据框写好建模、计算或绘图的函数；然后借助泛函式循环迭代，将函数依次应用到每个分组数据框上，其生成结果对象仍以列表列存放，只需按需展开、提取即可，整个过程无需编写显式循环。**当你能完成对"一份"数据的操作，那么对"一批"数据的操作便水到渠成**——这正是操作数据框思维、泛函式循环迭代、分组操作的汇聚点（范式 5：nest + map）。
"**每列**各一次"的批量（列不是组）同理：列向量天然是"一份"数据，用 `map()` 遍历列即可（速查 6.12）。

### 2.1 三种思维在本技能的落点

| 思维 | 落点（函数 / 范式） |
|---|---|
| 操作数据框思维 | 向量化：`mutate`/`summarise` 整列操作（各范式的地基）；函数式：自定义函数 + `across()`（速查 6.5）、`map` 遍历列（速查 6.12） |
| 数据分解思维 | 分组：`.by`（范式 2/3/4）、每组子数据框 `nest + map`（范式 5）；多列：`across()` |
| 操作分解思维 | 五步法第③步（基本操作序列）+ 管道 `\|>`；重塑环节的重载（范式 1 / 速查 6.7） |
| 汇聚点：批量建模/计算/可视化 | 按组：范式 5 `nest(.by = g) \|> mutate(data = map(data, f)) \|> unnest(data)`；按列：`map` 遍历列（速查 6.12） |

> **8 范式与三思维的归属**：范式 2/3/4 是"数据分解思维"的分组轴；范式 5 是三思维汇聚点（批量轴）；范式 1 与速查 6.7 是"操作分解思维"的重塑环节；范式 6/7/8 是"操作数据框思维"的函数式迭代与关系映射；`across`/速查 6.5/6.12 是"数据分解思维"的多列轴。

## 3. 五步数据思维法

> **拿到数据问题，先给形状预判，再写代码**：说明输出几列几行、分组粒度、每个操作的作用，然后才用管道实现。跳过分析直接堆代码是常见失败点。

| 步骤 | 关键动作 | 核心操作 |
|---|---|---|
| ① 理解目标 | 输入→输出形状？需要什么结构？ | 明确输出列、行数、分组粒度 |
| ② 重塑整洁 | 数据整洁吗？列名含信息吗？ | `pivot_longer` / `pivot_wider` / `separate_wider_*`（6.14） / `join` |
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
| 6 | 累计迭代 | 用上次算这次（永续盘存/递推）；简单累计和用 `cumsum` | `accumulate(序列[-1], ~ .x · .y, .init = first(序列))`；分组递推加 `.by`（**先 `arrange`，同 lag 行序前提**） |
| 7 | 滑窗迭代 | 窗口滚动 | 单值 `slide_dbl(x, mean, .before = 2, .complete = TRUE)`（分组加 `.by`，**先 `arrange`**）；多值 `slide()` |
| 8 | 非等连接 | 条件是 `>=`/`closest`/区间 | `left_join(lookup, join_by(closest(值 >= 阈值)))` |

> 每个范式的"何时用 / 思维轨迹 / 案例 / 注意"完整逻辑与多范式串联综合案例，见 [references/paradigms.md](references/paradigms.md)。

## 5. 决策树

拿到一个数据问题，依次问：

```
1. 数据整洁吗？
   ├─ 列名含信息（如 month_1, Q1, daw_1_） → 范式 1：pivot_longer
   ├─ 需要拆分列（如 "01-A001"） → separate_wider_*（速查 6.14）
   └─ 需要多表合并？ → left_join / right_join / bind_rows

2. 需要分组吗？
   ├─ 每组坍缩为一行 → 范式 2：summarise(.by=)
   ├─ 每组内修改列 → 范式 3：mutate(.by=)
   ├─ 行级筛选 → 范式 4：filter(.by=)
   ├─ 组级筛选（含某值则整组删） → 范式 4：filter(all(), .by=)
   ├─ 每组取最新/最大/前 N 行 → 速查 6.15：slice_max/slice_head
   ├─ 组内排名 → 速查 6.17：排名族
   ├─ 每组返回标量若干行 → reframe(.by=)（轻量）
   └─ 每组对子数据框复杂变换 → 范式 5：nest + map

3. 需要迭代/窗口吗？
   ├─ 序列有缺月/缺行 → 先补全网格（速查 6.16）
   ├─ 累计迭代（用上次结果算这次） → 范式 6：accumulate
   └─ 滑动窗口（相邻比较） → 范式 7：slide

4. 连接条件不是等号？
   └─ 范式 8：非等连接 join_by(closest())

5. 需要跨多列做同一操作？
   ├─ 每列返回兼容向量（如标准化、均值）且数据整洁 → across（速查 6.5）
   ├─ 每列返回兼容向量但数据不整洁 → 先 pivot_longer → 操作 → pivot_wider（速查 6.6）
   └─ 每列一个复杂对象（模型/图/检验） → map 遍历列（速查 6.12，总纲(4)）

6. 需要数据清洗？
   └─ 走数据清洗流程（缺失/异常/去重/审计）
```

## 6. 代码范型速查

> 本节是最短可复制写法；每个范式的"何时用 / 思维轨迹 / 案例 / 注意"完整逻辑见 [references/paradigms.md](references/paradigms.md)。范式代码改动后，跑 `scripts/verify_examples.R`（14 例）与 `scripts/verify_prompts.R`（3 题）一键回归，全 PASS 才收工。

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
# 简单累计和/累计积用 cumsum/cumprod；有递推系数或依赖前值才用 accumulate
df |> mutate(cum = cumsum(x))
df |> mutate(cum = accumulate(x[-1], ~ .x * 0.95 + .y, .init = first(x)))
# 分组递推：加 .by（逐组求值，各组从自己的首值起算；先 arrange 保证组内时间升序）
df |> mutate(K = accumulate(invest[-1], ~ .x * 0.95 + .y, .init = first(invest)), .by = region)
```

### 6.10 滑窗迭代
```r
library(slider)
df |> mutate(rolling_mean = slide_dbl(x, mean, .before = 2, .complete = TRUE))
# 分组滑窗：加 .by（逐组开窗互不串值；先 arrange 保证组内时间升序）
df |> mutate(rolling_mean = slide_dbl(sales, mean, .before = 2, .complete = TRUE), .by = store)
```

### 6.11 非等连接
```r
df |> left_join(lookup, join_by(closest(value >= threshold)))
```

### 6.12 按列批量（每列各算一个指标 / 各拟合模型 / 各画一张图）
```r
# across() 只适合返回兼容向量的汇总；"每列一个复杂对象"用 map 遍历列（列向量 = "一份"数据）：
tibble(col = names(df[-1]), mean = map_dbl(df[-1], \(x) mean(x, na.rm = TRUE)))
# 每列各拟合模型（⚠ df 里不要有名为 x 的列——公式会一直取它，各列结果就一样了）：
fits = tibble(col = names(df[-1]), fit = map(df[-1], \(x) lm(y ~ x, data = df)))
# 绘图：对"一份"数据写好画图函数后 map 过去（绘图语法本身不在本技能范围）
```

### 6.13 多表连接的键名不同
```r
df |> left_join(y, by = c("id" = "cust_id"))     # 左表 id 对右表 cust_id
# 或 by = join_by(id == cust_id)；⚠ bind_rows 是堆叠不是连接，别在"合并"名下混用
# ⚠ 同名列冲突默认加后缀 .x=左表/.y=右表，错引列即静默错值——语义化命名：
df |> left_join(y, by = "id", suffix = c("_订单", "_客户"))
```

### 6.14 拆分列（编码 → 多列，tidyr ≥1.3 的 separate_wider_*）
```r
df |> separate_wider_delim(编码, delim = "-", names = c("区号", "编号"))
# 按位宽拆：separate_wider_position(编码, widths = c(区号 = 2, 编号 = 4))  # widths 必须（部分）命名
# ⚠ 旧 separate() 已 superseded，新代码不再使用
```

### 6.15 组内取行（最新 / 最大 / 前 N）
```r
df |> slice_max(时间, n = 1, by = 客户)                      # 每客户最新 1 条（平局默认全保留）
df |> slice_max(时间, n = 1, by = 客户, with_ties = FALSE)   # 平局也只留 1 条
df |> slice_head(n = 2, by = 组)                             # 每组前 2 行
# 也可用范式 4：filter(时间 == max(时间), .by = 客户)——平局会保留多行，需形状预判时留意
```

### 6.16 补全组合网格（缺失组合填 0）
```r
df |> complete(地区, 月份 = 1:12, fill = list(销量 = 0))
# ⚠ 滑窗/累计（范式 6/7）前先补全，否则窗口错位静默算错
```

### 6.17 排名族（并列语义三选一）
```r
df |> mutate(rk = min_rank(-销量), .by = 门店)     # 并列同名次、跳号：1,1,3（综合案例同款）
df |> mutate(rk = dense_rank(-销量), .by = 门店)   # 并列同名次、不跳号：1,1,2
df |> mutate(rk = row_number(-销量), .by = 门店)   # 强制顺序（并列也分先后）：1,2,3
# 取名次而非排名用 6.15 slice_max；负号 = 降序排名
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
| 取反 `filter(!if_any(...))` | `if_any` 的 NA 传播：所选列含 NA 且其余列不匹配时，该行按 FALSE **静默丢弃** | 检测条件内先 `coalesce(x, "")` 兜底（详述见 references/paradigms.md 范式 4） |
| 累计/滑窗不先排序、不分组 | `accumulate`/`lag`/`slide_dbl` 依赖行内顺序，跨组/乱序**静默算错** | 先 `arrange(分组列, 时间列)`；分组递推/滑窗加 `.by`（范式 3/6/7 注意栏） |

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
- [ ] 代码模板改动后运行 `scripts/verify_examples.R`（14 例）与 `scripts/verify_prompts.R`（3 题），全 PASS 才收工？
- [ ] 文档计数改动后运行 `scripts/check_consistency.py`，57 项声明-实物对账全 PASS 才收工？（它同时管计数、文件引用、技能名一致性、跨技能契约与路由信号）
- [ ] 若改过技能名或引用，是否同步了 frontmatter `name`、README 标题与姊妹技能的全部引用？（改名属于"全仓一件事"，对账脚本会抓漏网）

## 11. 思维总结

> 拿到任何数据问题，先问三个问题：
> 1. **数据整洁吗？**（不整洁 → 先 pivot_longer）
> 2. **需要分组吗？**（分组 → `.by`；返回若干标量行 → `reframe`；子数据框变换 → nest+map）
> 3. **需要特殊的迭代方式吗？**（累计 → accumulate；滑动 → slide）
>
> 剩下的就是：**每一步只做一件事，用管道串起来。**

## 12. 综合案例与范式详述

8 范式的"何时用 / 思维轨迹 / 案例 / 注意"完整逻辑与多范式串联综合案例（范式1→3→4→6→2），见 [references/paradigms.md](references/paradigms.md)。可运行回归：`scripts/verify_examples.R`（14 例）、`scripts/verify_prompts.R`（3 题 7 检查）、`scripts/check_consistency.py`（57 项声明-实物对账）。人看的逐步案例（输入 → 定位 → 代码 → 真实输出）见 `examples/`；维护约定（对标观察清单、迭代纪律、下一轮入口）见 [MAINTAINING.md](MAINTAINING.md)。
