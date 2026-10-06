# Changelog

格式参考 [keepachangelog](https://keepachangelog.com/) 精神：每条讲清"为什么改"，不只"改了什么"。

## [Unreleased]

### Added
- **人看的案例 `examples/`（3 个）**：每个都是「用户原话 → 五步法定位 → 代码 → **真实输出**」，
  输出取自 `verify_prompts.R` 的同一夹具。此前仓库里只有"机器可跑的断言"，缺"人一眼看得懂的证据"——
  同行把结果摆首屏，我们只有断言。三例分别对应：宽表转长表 / 删整组 vs 删那一行 / 对抗 `for` 循环。
- **`MAINTAINING.md`**：对标观察清单（7 个同行 + 各自盯什么 + 什么信号触发行动）、迭代纪律、
  下一轮入口、已知边界损耗。交活不是终点——这份文档让下一轮从真实反馈进，不从零验料。

### Changed
- **技能更名**：`tidy-data` → `data-wrangling`。技能 id 即技能目录名，改名后 Claude Code / Codex /
  ZCode / OpenCode / WorkBuddy / OpenClaw 各运行时统一以 `data-wrangling` 发现本技能，与
  `data-cleaning` 的命名体系对齐（旧名 `tidy-data` 不再可触发）。
  同步改动：`SKILL.md` frontmatter `name`、`README.md` / `README.en.md` 标题与徽章标签、
  `scripts/verify_examples.R` 头注释、姊妹技能 `data-cleaning` / `write-zhihu` / `ml-mlr3`
  的全部引用与 `related-skills` 列表。
- 本文档本条目出现之前的 `tidy-data` 均指本技能旧名；对外仓库 slug 同步改为
  `github.com/zhjx19/data-wrangling`（GitHub 对旧 URL 自动重定向，已存在的旧链接不会断）。
- 首屏补一枚回归徽章（13 例 / 7 检查 / 声明-实物对账全 PASS）——同行普遍没有自证资产，
  把它从 README 末尾提到首屏。`description` 前置「定位器」定位句，补偿新名偏泛化。
- **对账脚本升级：从"只数数"扩到五类。** `check_consistency.py` 现在同时管
  ①**身份一致性**（目录名 = frontmatter `name` = README 标题）、②**跨技能契约**（`related-skills` 双向回指）、
  ③**旧名残留**（live 文档中不得再出现旧技能名，CHANGELOG 除外）、④**路由信号**（姊妹技能无授权占用
  本技能触发短语时红灯，已知重叠登记在白名单）、⑤**文档自报的检查总数**（对不齐即红灯）。
  起因是上次改名它能静默通过——**它根本不检查技能名，所以"漏改一处引用"这类错误它抓不住**。
  这正是"验证资产沉淀"：把一次性的人工 grep 立成仓库里跑得动的规矩。

- **路由占用清零**：`learning-method` 原在自己的 `references/tidyverse-style.md` 与 `SKILL.md` 里重述
  「数据思维」却不指向本技能；经其作者授权改为**明确委派**（注明完整框架在本技能、冲突以本技能为准，
  并列出超出其最小口径的范式指向本技能速查）。随之清空 `check_consistency.py` 的 `KNOWN_OVERLAPS`
  白名单——唯一的重叠既然修好了，就不该继续被豁免，否则白名单会遮蔽未来的回归。

## [1.4.0] — 2026-09-13 红队二轮补货 + 收尾工序

### Fixed
- **范式 7 滑窗分组/行序口径**（红队 C1，与范式 6 同型的静默翻车点）：`slide_dbl` 加 `.by`
  逐组开窗互不串值（回归第 12 例——B 组末行均值 200 而非跨店泄漏的 50，判别性断言）；
  详述补行序前提 + complete 回指；反模式表行名/机制/正解三者对齐。
- **join 同名列 .x/.y 零文档**（红队 C3）：速查 6.13 补 `suffix=` 语义化命名（第 11 例扩展），
  范式 8 案例把"用了不讲"的默认后缀机制讲清。
- **README 三处计数漂移**（红队 C9）：速查 11→17 段、范式例 9→13、反模式 11→12 条、
  Summary 样例 9/9→13/13。

### Added
- **排名族选型**（红队 C2）：速查 6.17——min_rank（并列跳号）/ dense_rank（并列不跳号）/
  row_number（强制顺序）三函数口径 + 组内排名（回归第 13 例）；范式 3 补分组排名案例。
- **收尾工序**：`scripts/check_consistency.py`——28 项"声明-实物"一致性对账（回归例数、
  速查段数、反模式行数、引用文件存在、stale 计数、superseded 函数残留），
  首跑即抓出全部文档漂移。**此后计数/引用改动必须过这道检查。**
- 决策树 Q2/Q3 补 6.15/6.16/6.17 上游入口（消除"单向门货架"）。

### Changed
- 决策树 Q5 三分支化（across / 先长后宽 / map 遍历列）。
- README.en.md 双语入口（house-style 语言互链）。

## [1.3.0] — 2026-09-13 红队一轮补货

### Fixed
- **范式 6 死引用**：案例 `.init = 基期资本` 未定义符号，改为 `.init = first(投资)`（组内取基期）。
- **separate 空引用**：决策树指向的 separate 在范式库/速查/环境表三处零出现，且已 superseded——
  改指 `separate_wider_*`（速查 6.14），与"现代 tidyverse"人设一致。
- 反模式表 NA 行补全前提（"所选列含 NA 且其余列不匹配时"），避免过度泛化。

### Added
- **范式 6 三口径**（红队 B1/A3，最危险的静默翻车点）：①cumsum/accumulate 选型（简单累计和用
  cumsum，有递推系数才用 accumulate）；②行序前提（同范式 3 的 lag，先 arrange，反模式表新行）；
  ③**分组递推生路**：`.by` 逐组求值使 `.init = first(投资)` 各组从自己首值起算——不均衡组实测正确
  （回归第 10 例），根治"照抄多组数据静默跨组串值"。
- **按列批量落点**（红队 A1/C2）：速查 6.12 `map` 遍历列（across 装不下模型/图）；决策树 Q5 三分支；
  落点表补全 8 范式与三思维归属（原为半张地图）；§1 可视化边界调和（绘图语法不管、批量组织管）。
- **速查补货 6.13–6.16**（红队 A4/B3/B4）：键名不同 `by = c()`、separate_wider_*、组内取行
  `slice_max(..., by=, with_ties=)`、`complete()` 补网格；回归第 11 例实证；环境表补两行。

### Changed
- 决策树 Q5 三分支化；Q1 空引用修复；bind_rows 澄清（堆叠非连接）。

## [1.2.0] — 2026-09-13 总纲入主

### Added
- **数据思维 2.0 总纲**：作者的核心数据编程思维导图（`assets/data-thinking-2.0.png`）+ 四点解读
  作为 §2 总的指导思想——三条核心思维（操作数据框思维 ← 向量化+函数式；数据分解思维 → 分组操作+
  同时操作多列；操作分解思维 ← 管道）与汇聚点（批量建模/计算/可视化 = 范式 5 nest+map）。
### Changed
- §2"核心理念"重构：原函数式操作分离 / 数据框思维 / 分组三合一 / 嵌套批量四小节，
  收拢为总纲三思维 + 落点映射表（原有内容全部保留在总纲解读与落点表中）。
- README 首屏嵌入总纲导图。

## [1.1.0] — 2026-09-12 鲁班精雕

### Fixed
- **回归脚本 locale 脆弱**：`verify_examples.R` 含 67 行中文，在 Git Bash 破损 LC_CTYPE 环境下
  R 解析直接中断（实测 0/8 静默失效）——整体 ASCII 化（标识符改英文、注释英文化），
  现在任意 locale 可跑。基线逻辑一字未变。

### Added
- **范式 4 新陷阱**：取反 `filter(!if_any(...))` 的 NA 传播会静默丢行——
  来自 data-cleaning skill 红队推演的实战发现，回归至此归属本技能管辖域。
  修法 `coalesce(x, "")` 兜底；反模式表新行 + 回归第 9 例实证。
- **frontmatter 可发现性**：补 Triggers 中英词表、`related-skills`（回指 data-cleaning）、
  `compatibility`（claude-code/zcode/opencode/codex）。
- **铁律双向同步契约**：data-cleaning 侧已有单向契约指向本技能 §9，此处补上回指，
  两份铁律任一改动必须双向同步。
- **prompt 实测回归**：`scripts/verify_prompts.R` 把 3 条 test-prompts 从 dry_run 升级为实跑断言
  （12 列宽表转长、环比+组级筛选、永续盘存 accumulate），7 检查。

### Changed
- **SKILL.md 下沉重构**：范式详述（何时用/思维轨迹/案例/注意）与综合案例下沉
  `references/paradigms.md`，主文件瘦身成定位器形态（23.5KB → 15.8KB）：
  快速定位表 + 五步法 + 范式速览表 + 决策树 + 速查留在主体。
- 自检清单补"交付前对照第①步形状预判"检查点。

## [1.0.0] — 2026-08-26 基线

- 8 范式框架 + 五步数据思维法 + 决策树 + 代码范型速查 + 反模式黑名单 + 破除外来思维 + 综合案例
- `verify_examples.R` 一键回归（8 范式 + 综合案例）；test-prompts.json 3 条
- 历史：dim2/3/5 三轮优化（accumulate 长度对齐、lag 排序前提、scoped 变体消歧、ml-mlr3 路由）
