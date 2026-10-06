# 真实案例（3 个）

这三个案例是技能的"before / after"：左边是**用户原话**，右边是**套用五步法后的定位 + 代码 + 真实输出**。它们和 `test-prompts.json` 一一对应，也和 `scripts/verify_prompts.R` 的夹具一一对应。

## 为什么要有这一层

README 里那句「30 秒定位到该用哪个范式」如果不配真实输出，就只是一句自夸。同行做得好的（见 `MAINTAINING.md` 对标观察清单）都在首屏摆结果；本目录就是把这个证据补上。

## 输出从哪来

**案例中的输出不是手写的**，是跑 `scripts/verify_prompts.R` 的同一套夹具（同一 `set.seed`）后原样抄回来的。三者的对应关系：

| 案例 | 对应 prompt | 守它的断言（`verify_prompts.R`） |
|---|---|---|
| [case-01 宽表转长表](case-01-wide-to-long.md) | `test-prompts.json` #1 | `P1 long shape 12 rows` · `P1 means match column means` |
| [case-02 分组环比 + 删缺失组](case-02-grouped-mom-and-complete-groups.md) | `test-prompts.json` #2 | `P2 only complete region survives` · `P2 complete-month count` |
| [case-03 永续盘存（对抗 for 循环）](case-03-perpetual-inventory.md) | `test-prompts.json` #3 | `P3 accumulate alignment` · `P3 recursion` · `P3 distinct replaces set logic` |

复跑（任意 locale）：

```bash
Rscript --vanilla scripts/verify_prompts.R    # === Summary: 7 check(s), 0 failure(s) ===
```

> 案例里为了可读性对数字做了显示用的 `round()`；断言用的是**未取整**的值（`abs(diff) < 1e-9`），所以展示层取整不影响回归强度。

## 三个案例各自想证明什么

1. **case-01**：列名含信息时，第一步永远是重塑——而不是先去想 `summarise` 怎么写。
2. **case-02**：一件事一个函数（`mutate` 算环比、`filter` 删组、`summarise` 计数），且**组级筛选是删整组不是删行**。
3. **case-03**：最容易被写成 `for` 循环的递推，用 `accumulate` 三行解决——这条是反直觉的那条，所以单独留一个案例。
