# 维护与迭代纪律

> 交活不是终点。这份文档固定三件事：**对标观察清单**（同行在动什么）、**迭代纪律**（每次改动必须做什么）、**下一轮入口**（明确写下来，不靠记忆）。

## 一、迭代纪律

### 1. 提交前必须跑的三条命令（缺一条即视为未完成）

```bash
Rscript --vanilla scripts/verify_examples.R    # 14 例范式代码回归
Rscript --vanilla scripts/verify_prompts.R     # 3 题 prompt 端到端断言
python scripts/check_consistency.py            # 声明-实物对账（自报总数以运行输出为准）
```

第三条不只是数数——它同时管**身份一致性、跨技能契约、路由信号**（见第五节）。**任何文档改动或改名改动，都必须让它全绿。**

### 2. 三条硬规矩

- **改名 = 全仓一件事。** 技能 id 就是技能目录名，所以改名必须同步：frontmatter `name`、README/README.en 标题、姊妹技能的 `related-skills` 与正文引用、`scripts/*.R` 头注释，并在 CHANGELOG 留一条"为什么改"。漏哪一处，`check_consistency.py` 会红灯。
- **计数与引用改了就跑对账。** 文档里的数字必须等于实物的实际数量；这一条是历史红队最爱抓的漂移点。
- **回刀不用 `git reset --hard`。** 优先 `git revert` 或追加一个修正提交，保留可审计的 diff。

### 3. 发版叙事

每条 CHANGELOG 回答**"为什么改"**，不只"改了什么"。历史条目保持原样（技能更名前的老条目里写的旧名就是它当时的样子）；跨版本的**更名/破坏性变动**单列一段说明影响面。

### 4. 提交粒度

一个提交只改一个面。改名那次就是"单提交单面"的样板——如果以后再改名，照那个提交的样子做。

## 二、对标观察清单

访行时摸到的同行，留下要盯的具体点位，下次从真实反馈进，不从零验料。

| 同行 | 链接 | 盯什么 | 什么信号触发行动 |
|---|---|---|---|
| Tessl Registry | https://tessl.io/registry/skills | 它的 "agent success vs baseline" 量化信任是否成为技能市场默认展示 | 若成为默认 → 把本技能的回归升级成对外可跑的评分卡，而不只是仓库内脚本 |
| skills.sh 条目 | https://www.skills.sh/skills/zhjx19/data-wrangling | 条目是否随仓库改名生效、是否进入 curated 分类 | 条目缺失或指向旧 slug → 修 README 徽章与安装命令 |
| tidy-r-skill | https://github.com/statzhero/tidy-r-skill | 是否补上"问题→范式定位"层（那是本技能的差异点） | 若它也加定位层 → 差异化回到"回归自证"上 |
| writing-tidyverse-r | https://lobehub.com/skills/jeremy-allen-claude-skills-writing-tidyverse-r | 多平台目录曝光的具体做法 | 若它靠多平台目录获得曝光 → 补 ClawHub/Tessl 投放 |
| Claude R Tidyverse Expert | https://gist.github.com/sj-io/3828d64d0969f2a0f05297e59e6c15ad | 第三方盘点文的背书渠道（R Works 那类文章） | 出现新的 R 技能盘点文 → 争取被收录 |
| csv-data-wrangler | https://www.aibuilderclub.com/blog/claude-code-for-data-scientists-skills-guide | 是否挤占 `data-wrangling` 的检索语义 | 若被误装 → 首屏把"定位器"顶到更前 |
| R Works 盘点文 | https://rworks.dev/posts/claude-skills-for-r-users | R 用户技能盘点类文章的收录口径 | 有新版盘点 → 主动投递 |
| 姊妹技能 data-cleaning | 本地同源目录 | 两份 R 铁律的双向同步契约 | 任一侧改铁律 → 另一侧必须同步（已由对账脚本兜住回指） |

## 三、下一轮入口（按价值排序）

1. **触发准确率的真机 eval。** 当前只有离线信号检查（见第四节边界损耗）；真测需要跑 agent 选择回路，缺这个场。
2. **决策树一页图 + 30 秒 GIF。** 决策树现在还是 SKILL.md 里的文本代码块；转图即可截图传播。
3. **速查 6.12 补可跑代码。** 它只给了"每列各画一张图"的方向，没给可运行片段——与其他 16 段速查的强度不一致。

## 四、已知边界损耗（明写下来，不假装没有）

- **触发准确率无法离线测量。** `check_consistency.py` 只能验证"选择所依赖的信号齐不齐"（triggers 声明、负面边界、姊妹技能是否无授权占用我们的短语），**不能证明 agent 真的会选中它**。
- **无 GIF / 决策树一页图。** 仓库里唯一可展示产物仍是一张思维导图；录制与图形生成工具未纳入本仓库依赖，故本轮未做。
- **`learning-method` 的短语重叠已消除。** 它原先在自己的 `references/tidyverse-style.md` 与 `SKILL.md` 里
  重述「数据思维」却不指向本技能；经其作者授权后改为**明确委派**：两处注明"完整框架在 `data-wrangling`、
  口径冲突以它为准"，并在文末列出超出其最小口径的范式（`accumulate` / `slide` / `join_by(closest)` /
  `filter(all(), .by=)` / `slice_max(..., by=)` / `complete()`）指向本技能速查，**要求不要另起一套写法**。
- **`KNOWN_OVERLAPS` 白名单已清空。** 既然唯一的重叠已修好，就把它从豁免名单里撤掉——否则白名单会变成
  遮蔽未来回归的遮挡物。现在任何姊妹技能重述本技能触发短语而不委派，一律硬红灯（双向已实测）。
- **分发链接不在本仓库管辖范围。** 若用符号链接把技能分发到多个 runtime 目录，改名时请同步重建；系统不允许创建符号链接时，目录联接（junction）是等价替代。

## 五、验证资产清单（沉淀，不是脚手架）

| 资产 | 守什么 | 什么时候必须跑 |
|---|---|---|
| `scripts/verify_examples.R` | 14 例范式代码在当前 tidyverse 版本下可跑 | 改任何范式代码或速查后 |
| `scripts/verify_prompts.R` | 3 条行为 prompt 的端到端输出断言 | 改 `test-prompts.json` 或范式后 |
| `scripts/check_consistency.py` | 计数 / 文件引用 / **身份一致性** / 跨技能契约 / 路由信号 / 自报总数 | 任何文档改动、任何改名 |
| `examples/` | 给人看的 before/after 证据（输出取自 `verify_prompts.R` 同一夹具） | 与 `verify_prompts.R` 同源，**改其一必改另一** |

### 对账脚本的判据（已负向实测）

在临时沙盒里把技能复制成 `data-wrangling/`（配一个 stub 姊妹技能），基线全绿，然后逐个施加破坏并记录红灯范围——**要证明这些检查是"精准的"，而不是"一碰就全红"**：

| 施加的破坏 | 红灯范围 |
|---|---|
| frontmatter `name` 与目录名不一致 | 5 项（name + 两个 README 标题 + 姊妹回指 + 旧名残留）。改名本就是级联改动，红灯级联是**正确**行为 |
| README 标题丢掉技能 id | 1 项 |
| live 文档里残留旧技能名 | 1 项 |
| 姊妹技能占用本技能触发短语且不指向本技能 | 1 项 |
| 删掉一个 `examples/` 案例文件 | 2 项（文件存在 + 案例计数） |
| 文档自报的检查总数对不上实际 | 1 项 |

> 这张表的用法：下次有人问"这个脚本管不管我这件事"，看表即可。**若某个破坏在上表里却没有红灯，说明该维度的检查退化了**——那才是要修的地方。

## 六、本轮明确不做

- 不替**未授权**的技能做判断：`learning-method` 那次改动是拿到该作者明确授权后才做的。没有授权的重述，登记进 `KNOWN_OVERLAPS` 并写明理由，不擅自改别人的文档。
- 不给 `examples/` 加第二套自动断言——会造出双份真相，与"单一事实源"冲突。
- 不引入任何新依赖：四个脚本刻意保持零依赖、任意 locale 可跑。
