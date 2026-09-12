# 范式详述与综合案例

> 本文件是 SKILL.md §4（实战范式库）与 §12（综合案例）的完整载体。主文件是定位器：
> 快速定位表 + 决策树 + 速查；这里是每个范式的"何时用 / 思维轨迹 / 案例 / 注意"完整逻辑。
> 所有代码已收敛到 `scripts/verify_examples.R`（13 例）与 `scripts/verify_prompts.R`（3 题 7 检查）回归，改动后跑一遍全 PASS 才收工。

## 范式 1：列名含信息 → 先宽变长

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

## 范式 2：分组汇总（每组坍缩为一行）

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

## 范式 3：分组修改（保持原行数，每组内计算）

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

分组排名也是本范式的典型场景（排名族并列语义三选一见速查 6.17）：
```r
df |> mutate(店内排名 = min_rank(-销售额), .by = 门店)
```

## 范式 4：分组筛选（选每组中的子行或整组）

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

## 范式 5：nest + map（法宝模式）—— 分组后每组操作产生不同行数

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

## 范式 6：累计迭代（accumulate）

**何时用**：需要"用上次结果计算这次结果"的累计运算——累计和、永续盘存、递推公式。

> **选型口径**：简单累计和/累计积直接用 `cumsum()` / `cumprod()`（纯向量化）；**有递推系数或依赖前值计算**（如永续盘存 K_t = K_{t-1}×0.95 + I_t）才用 `accumulate()`。

```r
# accumulate(序列, 二元函数, .init = 启动值)
# .x = 上次累计结果或启动值, .y = 序列当前值
# ⚠ 带 .init 时返回长度 = 序列长度 + 1（首元素是启动值）；放进 mutate 须用 序列[-1]，见下注意

df |> mutate(累计结果 = accumulate(序列[-1], ~ .x * .y / 100, .init = 启动值))
```

> **注意（长度对齐）**：带 `.init` 的 `accumulate` 返回长度 = 序列长度 + 1（首元素为启动值），直接放进 `mutate` 会行数错位。统一写法为 `accumulate(序列[-1], ..., .init = 首值)`——去掉序列首元素后输出长度恰好等于行数（首行即启动值）。

> **注意（行序，同范式 3 的 lag）**：`accumulate` 依赖行内顺序——使用前先 `arrange(分组列, 时间列)`，乱序数据会**静默算错**。

> **注意（分组递推）**：多个分组各自递推时直接加 `.by`——`.by` 逐组求值使 `序列[-1]` 与 `.init = first(序列)` 都在组内生效，各组从**自己的首值**起算，长度自动对齐（回归实证：`scripts/verify_examples.R` 第 10 例，组数不均衡亦正确）：
>
> ```r
> # 每个地区分别做永续盘存（先 arrange 保证组内时间升序）
> df |>
>   arrange(地区, 年份) |>
>   mutate(资本存量 = accumulate(投资[-1], ~ .x * 0.95 + .y,
>                                .init = first(投资)), .by = 地区)
> ```
> `.init = first(投资)` 取**各组的首个投资额**为基期——不要照抄教程里未定义的"基期资本"占位符。若需对每组做更复杂变换（多列状态、输出多列），走范式 5 nest + map。

**案例**（永续盘存法计算资本存量，K_t = K_{t-1}(1-δ) + I_t）：
```r
df |> 
  mutate(基期指数 = accumulate(价格指数[-1], ~ .x * .y / 100, .init = 100),
         资本存量 = accumulate(固定资产投资[-1], ~ .x * (1 - 0.05) + .y,
                               .init = first(固定资产投资)))
```

## 范式 7：滑窗迭代（slide）

**何时用**：需要"窗口滚动计算"——滚动均值、相邻比较、滑动窗口内操作。

> **注意（行序与空洞，同范式 3/6）**：slide 依赖行内顺序——先 `arrange(分组列, 时间列)`；序列有缺月/缺行先 `complete()` 补全网格（速查 6.16），否则窗口错位**静默算错**。

> **注意（分组滑窗）**：分组滚动直接加 `.by`——`.by` 逐组求值使 slide_dbl 在**各组内部**开窗，互不串值（回归实证：`scripts/verify_examples.R` 第 12 例——B 组末行均值 200 而非跨店泄漏的 50）：
>
> ```r
> df |>
>   arrange(门店, 日期) |>
>   mutate(滚动均值 = slide_dbl(销量, mean, .before = 2, .complete = TRUE), .by = 门店)
> ```
> 单值用 `slide_dbl`；每组返回多值（如"较上期增/减各几项"）用 `slide()`，嵌套形态见下案例。

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

> **slide vs slide_dbl 口径**：`slide()` 每个窗口可返回**任意长度**（可多元素，如上面"减少/增加"两值），窗口不完整时按 `.complete` 返回部分窗口或 NULL；`slide_dbl()` 强制每个窗口返回**单个数值**（适合 `mutate` 标量新列，如滚动均值），不完整窗口 `.complete=TRUE` 时返回 `NA`。单值用 `slide_dbl`（见速查 6.10），多值用 `slide`。

## 范式 8：非等连接

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
# .x/.y 是 join 同名列冲突的默认后缀（.x=左表/.y=右表）；为可读性建议 join 时显式
# suffix = c("_时长", "_开播日") 命名（速查 6.13），再 pmin(奖励系数_时长, 奖励系数_开播日)
```

> **非等连接三形态**（dplyr ≥1.1）：`join_by(值 >= 阈值)` 按不等式连接（可多行匹配，全部满足档都会连上）；`join_by(closest(值 >= 阈值))` 每个左行只取最接近的一档；`join_by(within(区间))` / `join_by(overlap(区间))` 处理区间包含 / 重叠。选型：只取最近一档 → `closest`；要列出全部满足档 → 直接用 `>=`；区间匹配 → `within` / `overlap`。

## 综合案例（多范式串联）

> 一个真实感的完整例子，把 范式1→3→4→6→2 串起来；完整可运行脚本见 `scripts/verify_examples.R`（13 例一键回归）。

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
