# case-02：分组环比 + 删掉有缺失的整组 + 数完整月数

## 用户原话

> 数据 df 是各地区每月的销售额，我要算每个地区的环比增长率（本月/上月-1），并且把任何一个月数据缺失的地区整组删掉，最后还要能看出每个地区有多少个完整月份。

## 五步法定位

三件事，**一件事一个函数**（这是本技能的核心纪律：不要憋一个巨复杂的 `summarise`）：

| # | 要做的事 | 落在哪个范式 / 函数 |
|---|---|---|
| 1 | 组内算环比（行数不变） | **范式 3 分组修改** → `mutate(..., .by = region)`；`lag` 前先 `arrange` |
| 2 | 有任一缺失就删**整组** | **范式 4 组级筛选** → `filter(all(!is.na(sales)), .by = region)` |
| 3 | 每组数完整月数 | **范式 2 分组汇总** → `summarise(n(), .by = region)` |

**关键区分**：第 2 步是**组级筛选**（`filter(all(条件), .by=)`），不是行级筛选（`filter(条件, .by=)`）。写成行级就变成"删掉那一行"，而用户要的是"这个地区整块不要了"——**这是本案例最容易错的一步**。

## 数据（`set.seed(7)`，地区 A 的前 6 个月）

```
 region month sales
      A     1    99
      A     2    NA
      A     3    20
      A     4    16
      A     5    32
      A     6    81
```

A 的第 2 月缺失、C 的第 3 月缺失（B 完整）。

## 代码

```r
df2 |>
  arrange(region, month) |>                          # 环比依赖行序
  mutate(mom = sales / lag(sales) - 1, .by = region) |>   # 范式 3
  filter(all(!is.na(sales)), .by = region) |>        # 范式 4（组级）
  summarise(n_complete = sum(!is.na(sales)), .by = region)  # 范式 2
```

注意 `arrange(region, month)` 不是可选项：`lag()` 按**行内顺序**取值，不先排序就会拿上一组的末行当月上一月，**静默算错**（反模式表专门收了这一条）。

## 真实输出

```
 region n_complete
      B          6
```

A 与 C 整组消失（各有一个缺失月份），只剩 B —— 这正是「整组删」而不是「删那一行」的证据。

## 这个案例守住了什么

- `P2 only complete region survives` —— 集合相等断言 `setequal(region, "B")`。如果误写成行级 `filter`，A/C 会残留 5 行，立刻红灯。
- `P2 complete-month count` —— `n_complete == 6`，确认"完整月数"是按组口径数出来的。

## 常见走偏

- ❌ `filter(!is.na(sales), .by = region)` → 只删那一行，A/C 仍在（用户要的是删组）。
- ❌ 用 `mean(is.na(sales)) < 0.5` 这类阈值 → 语义变了（容忍部分缺失），要的是"一个都不能缺"。
- ❌ 不 `arrange` 直接 `lag` → 行数对、`mom` 错，最坏的一类 bug。
- ❌ 三个需求挤进一个 `summarise` → 可读性崩，且删组逻辑塞不进去。
