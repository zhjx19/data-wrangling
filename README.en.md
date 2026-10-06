<sub>🌐 <a href="README.md">中文</a> · <b>English</b></sub>

<div align="center">

# data-wrangling · Data Thinking

> *「Most data problems can be solved with one way of thinking: reshape to tidy, decompose into primitives, then pipe it all together.」*

[![Agent Skills](https://img.shields.io/badge/Agent_Skills-data--wrangling-blueviolet)](SKILL.md)
[![R](https://img.shields.io/badge/R-tidyverse-blue)](https://www.tidyverse.org/)
[![regression](https://img.shields.io/badge/regression-13%2F13%20%C2%B7%207%2F7%20%C2%B7%2028%2F28%20PASS-brightgreen)](scripts/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![skills.sh](https://skills.sh/b/zhjx19/data-wrangling)](https://skills.sh/zhjx19/data-wrangling)

**Not another tidyverse function reference — a problem→paradigm locator: for any tabular data problem, reach the right paradigm in 30 seconds.**

[See it work](#see-it-work) · [Install](#quick-start) · [Triggers](#triggers) · [How it differs](#how-it-differs) · [Verification](#verification--testing)

</div>

---

## What problem does it solve?

Knowing dplyr's functions is not the same as solving data problems. The real bottleneck is never "how do I spell pivot_longer" — it is **staring at a table and not knowing the first move**: reshape to long first, or group first? `.by` or nest+map? Can this for loop be vectorized?

This skill fixes a "data thinking" framework into a decision structure. Its guiding mind map (**Data Thinking 2.0**, `assets/data-thinking-2.0.png`, labels in Chinese — SKILL.md §2 gives the gloss) collapses everything into three core thinkings plus one convergence point:

- **Operate-on-dataframe thinking** — vectorization (operate on a whole column, multiple columns, or each group's columns) and functional programming (write the function once, apply it across columns) absorbed into the data frame itself;
- **Data decomposition thinking** — grouping (`.by`, nest+map) and multi-column operations (`across()`): the function handles "decompose + operate per piece + combine results", you only write the *operate-per-piece* part;
- **Operation decomposition thinking** — any complex operation decomposes into primitives (joins, reshapes, sorting, selecting, mutating, summarising), chained with the pipe;
- **Convergence: batch modeling / computation / visualization** — pack the data frame into a nested frame with list-columns, write the function for *one* piece, then map it over every group. Once you can operate on "one piece", operating on "a batch" follows naturally (Paradigm 5: nest + map).

Laid out as an executable structure: a **five-step method** (shape prediction → tidy → decompose → vectorize → verify), **8实战 paradigms** (one per problem signal), and a **foreign-habit correction list** (Python-style list/for-loop/set thinking). Once the thinking is clear, §6 gives you the shortest copy-paste code.

## See it work

```text
You: I have a wide table with month_1 through month_12 as columns. I want the
     average sales per month, output as a long table (month, mean_sales).

Agent: (five-step method) ① shape prediction: a 12-row long table
       → ② info lives in column names → Paradigm 1, pivot to long
       → ③④ summarise(.by = month) → ⑤ pipe it:

      df |>
        pivot_longer(-id, names_pattern = "month_(\\d+)",
                     names_to = "m", values_to = "sales") |>
        summarise(mean_sales = mean(sales), .by = m)
```

Or: **"I want a for loop to compute capital stock row by row (perpetual inventory)"** → Paradigm 6 `accumulate(.init=)` in three lines, plus the mind-correction for why the loop is the wrong reflex. All 8 paradigms: [SKILL.md quick-locator table](SKILL.md).

## Quick start

**Prerequisites**: this skill generates and runs R code — you need R installed (≥4.2 recommended, with dplyr ≥1.1, tidyr ≥1.3, purrr, slider).

Install into your agent's skills directory (SKILL.md format; works with Claude Code / ZCode / OpenCode / Codex):

```bash
npx skills add zhjx19/data-wrangling             # one-line install via skills.sh
# or clone manually (repo name = skill name, so the directory and id match):
git clone https://github.com/zhjx19/data-wrangling && cp -r data-wrangling ~/.claude/skills/
```

Then say to your agent:

```text
Solve this R data problem with the data-thinking framework: … (describe your
table and goal)
```

## Triggers

- "how do I write this in R tidyverse?" / "solve it with data thinking"
- "wide to long" / "long to wide" / "the month is baked into my column names"
- "grouped month-over-month" / "per-group TopN"
- "drop groups containing missing values" / "fit a model per group"
- "vectorize this cumulative recursion" / "rolling mean"
- "I don't want a for loop — what's the R way?"

## What does it deliver?

| Capability | Deliverable |
|---|---|
| Problem → paradigm locating | Quick-locator table + decision tree (in SKILL.md) |
| Paradigm thinking | 8 paradigms: when to use / thought trajectory / case / caveats (references/paradigms.md) |
| Copy-paste code | 17 shortest-form snippets (SKILL.md §6) |
| Mind corrections | 12-row anti-pattern blacklist + 6 "break foreign habits" questions |
| Quality assurance | Triple regression: 13 paradigm cases + 3 prompt tests + 28 doc-vs-reality checks |

## How it differs

| Dimension | Reference-style skills (tidy-r-skill, tidyverse-patterns…) | This skill |
|---|---|---|
| Positioning | Teaches "how to write correct code" | Teaches "how to think about the problem": signal → paradigm |
| Organization | By function / topic | By problem signal (8 paradigms + decision tree) |
| Mind corrections | Rare | A dedicated section against Python-style loop/list/set thinking |
| Quality assurance | Sometimes described | Triple regression (13 + 3 + 28), locale-proof, one command |

## Safety boundaries

- **No plotting**: the ggplot2 grammar is out of scope (see the ggplot2 skill); but the *batch organization* of "one chart per column/group" is covered.
- **No formal modeling**: nest+map per-group modeling is lightweight exploration; for proper predictive workflows (resampling, tuning, benchmarks) use the `ml-mlr3` skill.
- **No data cleaning**: dirty-data audits and cleaning belong to the `data-cleaning` skill (this skill backstops its structural transformations).
- **Version floor**: `.by`/`reframe` need dplyr ≥1.1, `nest(.by=)` needs tidyr ≥1.3 — older versions fail loudly.

## File structure

```text
├── SKILL.md                    Locator: overview + five-step method + paradigm index + decision tree + snippets
├── references/paradigms.md     8 paradigms in full (when / trajectory / case / caveats) + capstone case
├── scripts/verify_examples.R   13 paradigm-case regressions (locale-proof)
├── scripts/verify_prompts.R    3 prompt-level regression tests
├── scripts/check_consistency.py 28 doc-vs-reality consistency checks
├── test-prompts.json           3 behavioral test prompts
├── assets/data-thinking-2.0.png Data Thinking 2.0 mind map
└── CHANGELOG.md                Version history
```

## Verification & testing

```bash
Rscript --vanilla scripts/verify_examples.R   # === Summary: 13/13 PASS ===
Rscript --vanilla scripts/verify_prompts.R    # === Summary: 7 check(s), 0 failure(s) ===
python scripts/check_consistency.py           # 28 doc-vs-reality checks, all PASS
```

Behavioral tests live in [test-prompts.json](test-prompts.json), including one adversarial
prompt — "I want a for loop to iterate row by row" — where correct behavior is to break the
loop habit and vectorize with `accumulate`, not to comply.

## Acknowledgments

- Methodology sharpened in the Luban workshop (audit → peer scan → measure → carve);
  peer benchmarks: [tidy-r-skill](https://github.com/statzhero/tidy-r-skill), [tidyverse-patterns](https://www.skills.sh/s/ab604/claude-code-r-skills/tidyverse-patterns)
- Sister skill `data-cleaning`: audit-first cleaning; this skill backstops its reshaping, grouping and recurrence needs

## License

[MIT](LICENSE)
