#!/usr/bin/env python3
# make_figures.py -- 生成 assets/ 里的两张图：
#   decision-tree.png / .svg   静态决策树（README 参考版，可打印）
#   demo.gif                   定位过程示意（逐问揭示；脚本合成，非录屏）
#
# 设计原则：图从 SKILL.md §5「决策树」与 §3「五步数据思维法」**解析**而来，
# 不手抄——文档改了图就跟着变，且解析不到预期结构时直接报错（宁可失败，不要
# 悄悄画一张过期的图）。
#
# 依赖：matplotlib + Pillow（仅此脚本需要；仓库的四个验证脚本仍保持零依赖）。
# 用法：python assets/make_figures.py            # 从仓库根或任意目录均可
#
# 注意：本脚本的 print 一律 ASCII，避免 Windows 控制台编码问题（同 verify_*.R 的教训）。

import io
import os
import re
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")

# ---- 字体：显式注册一个中文 TTF（simhei 是纯 TTF，比 .ttc 稳）-----------------
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\Deng.ttf",
    r"C:\Windows\Fonts\simkai.ttf",
]
FONT_PATH = next((p for p in FONT_CANDIDATES if os.path.isfile(p)), None)
if FONT_PATH:
    matplotlib.font_manager.fontManager.addfont(FONT_PATH)
    FONT_FAMILY = matplotlib.font_manager.FontProperties(fname=FONT_PATH).get_name()
else:
    FONT_FAMILY = "sans-serif"
matplotlib.rcParams["font.family"] = FONT_FAMILY
matplotlib.rcParams["axes.unicode_minus"] = False
# SVG 里把字转成路径：任何环境都渲染得出中文，不依赖对方装了什么字体。
matplotlib.rcParams["svg.fonttype"] = "path"

# ---- 调色 ---------------------------------------------------------------------
INK = "#1f2d3d"       # 题头底色
PAPER = "#fbfbf9"     # 画布
LABEL = "#2b2b2b"     # 分支文字
C_PARA = ("#eaf5ee", "#2f6f4f")   # 范式 N
C_QUICK = ("#fdf3e3", "#8a5a00")  # 速查 6.x
C_OTHER = ("#ececfa", "#4a4a8a")  # 其他（reframe / 连接 / 边界外说明）

# ---- 版面常量（轴坐标单位；1 单位 ≈ 0.285 英寸）------------------------------
ROW = 0.60        # 一条分支占的高度
QH = 0.78         # 题头带 + 其下留白
QGAP = 0.24       # 一个问题块之后的间隔
HEAD = 1.20       # 标题区
FOOT = 0.95       # 页脚区
INCH_PER_UNIT = 0.285


def read_skill():
    with open(os.path.join(ROOT, "SKILL.md"), encoding="utf-8") as f:
        return f.read()


def parse_tree(text):
    """-> [(question, [(glyph, label, target), ...]), ...]  from SKILL.md §5.

    `label is None`  => 该行本身就是目标（如 Q4「└─ 范式 8：非等连接 …」）。
    `target is None` => 该行不指向范式，而是交给别的技能（Q6 -> data-cleaning）。
    """
    sec = text.split("## 5. 决策树", 1)
    if len(sec) != 2:
        raise SystemExit("[ABORT] SKILL.md: '## 5. 决策树' not found")
    body = sec[1].split("```", 2)
    if len(body) < 2:
        raise SystemExit("[ABORT] SKILL.md: decision-tree code fence not found")
    tree, cur = [], None
    for line in body[1].splitlines():
        m = re.match(r"^(\d+)\.\s+(.+?)\s*$", line)
        if m:
            cur = (m.group(2), [])
            tree.append(cur)
            continue
        m = re.match(r"^\s*([├└])─\s+(.+?)\s*$", line)
        if m and cur is not None:
            glyph, s = m.group(1), m.group(2).strip()
            if " → " in s:
                label, target = s.split(" → ", 1)
                cur[1].append((glyph, label.strip(), target.strip()))
            elif re.match(r"^(范式|速查)", s):
                cur[1].append((glyph, None, s))
            else:
                cur[1].append((glyph, s, None))
    if len(tree) != 6 or sum(len(b) for _, b in tree) != 19:
        raise SystemExit("[ABORT] parsed {} question(s) / {} branch(es); "
                         "expected 6 / 19 -- SKILL.md §5 changed shape, "
                         "update this script".format(
                             len(tree), sum(len(b) for _, b in tree)))
    return tree


def parse_steps(text):
    """-> ['理解目标', ...] from the §3 five-step table (① .. ⑤)."""
    sec = text.split("## 3. 五步数据思维法", 1)
    if len(sec) != 2:
        raise SystemExit("[ABORT] SKILL.md: '## 3. 五步数据思维法' not found")
    steps = re.findall(r"^\|\s*[①②③④⑤]\s*([^|]+?)\s*\|", sec[1], re.M)
    if len(steps) != 5:
        raise SystemExit("[ABORT] parsed {} step(s); expected 5".format(len(steps)))
    return steps


def chip_colors(target):
    if "范式" in target:
        return C_PARA
    if "速查" in target:
        return C_QUICK
    return C_OTHER


def canvas_height(tree):
    return HEAD + sum(QH + ROW * len(b) + QGAP for _, b in tree) + FOOT


def draw(tree, steps, reveal=None, current=None, show_footer=False):
    """Draw the tree. reveal=None -> everything; else the first `reveal` blocks.

    The canvas is always sized for the FULL tree so the GIF's text never rescales.
    """
    show = tree if reveal is None else tree[:reveal]
    H = canvas_height(tree)

    fig = plt.figure(figsize=(11.0, H * INCH_PER_UNIT), dpi=100)
    fig.patch.set_facecolor(PAPER)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_facecolor(PAPER)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, H)
    ax.axis("off")

    ax.text(0.5, H - 0.55, "拿到一个数据问题 → 依次问 6 个问题 → 落到范式",
            ha="center", va="center", fontsize=15, color=INK, weight="bold")

    y = H - HEAD
    for qi, (q, branches) in enumerate(show, start=1):
        dim = 1.0 if (current is None or current == qi) else 0.45
        ax.add_patch(Rectangle((0.035, y - 0.42), 0.93, 0.52,
                               facecolor=INK, edgecolor="none", alpha=dim))
        ax.text(0.055, y - 0.16, "{}. {}".format(qi, q), ha="left", va="center",
                fontsize=12.5, color="white", weight="bold",
                alpha=1.0 if dim == 1.0 else 0.8)
        y -= QH
        for glyph, label, target in branches:
            ax.text(0.075, y, glyph + "─ " + (label if label else ""),
                    ha="left", va="center", fontsize=9.5, color=LABEL)
            chip_x = 0.60 if label else 0.135
            if target is None:
                ax.text(chip_x, y, "（交给 data-cleaning 技能）", ha="left",
                        va="center", fontsize=9, color="#8a8a8a", style="italic")
            else:
                fc, ec = chip_colors(target)
                ax.text(chip_x, y, target, ha="left", va="center", fontsize=9.5,
                        color=ec, weight="bold",
                        bbox=dict(boxstyle="round,pad=0.34", fc=fc, ec=ec, lw=0.8))
            y -= ROW
        y -= QGAP

    if reveal is None or show_footer:
        ax.text(0.5, FOOT * 0.42,
                "五步法：{}　|　源：SKILL.md §3 §5（本图由 assets/make_figures.py 解析生成）".format(
                    " → ".join(s.strip() for s in steps)),
                ha="center", va="center", fontsize=9, color="#6b6b6b")
    return fig


def main():
    text = read_skill()
    tree = parse_tree(text)
    steps = parse_steps(text)
    print("[parse] {} questions / {} branches / {} steps".format(
        len(tree), sum(len(b) for _, b in tree), len(steps)))

    fig = draw(tree, steps)
    png = os.path.join(ASSETS, "decision-tree.png")
    svg = os.path.join(ASSETS, "decision-tree.svg")
    fig.savefig(png, dpi=170, facecolor=PAPER)
    fig.savefig(svg, facecolor=PAPER)
    plt.close(fig)
    for f in (png, svg):
        print("[static] {} ({:.0f} KB)".format(os.path.basename(f),
                                               os.path.getsize(f) / 1024))

    # ---- GIF: 0 = 只有标题；1..6 = 逐问揭示；7 = 收尾（补页脚）----------------
    plans = [(0, None, False)] + [(k, k, False) for k in range(1, len(tree) + 1)] \
        + [(len(tree), len(tree), True)]
    durations = [1400] + [1100] * len(tree) + [2800]
    frames = []
    for reveal, current, foot in plans:
        f = draw(tree, steps, reveal=reveal, current=current, show_footer=foot)
        buf = io.BytesIO()
        f.savefig(buf, format="png", dpi=96, facecolor=PAPER)
        plt.close(f)
        buf.seek(0)
        frames.append(Image.open(buf).convert("RGB").quantize(colors=64))
    gif = os.path.join(ASSETS, "demo.gif")
    frames[0].save(gif, save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, optimize=True)
    print("[gif] {} frames, {} ({:.0f} KB), total {:.1f}s".format(
        len(frames), os.path.basename(gif), os.path.getsize(gif) / 1024,
        sum(durations) / 1000))


if __name__ == "__main__":
    sys.exit(main())
