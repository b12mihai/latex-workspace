---
name: latex-to-docx
description: >
  Use this skill whenever the user provides a LaTeX (.tex) file and wants it converted
  to a Word document (.docx). This skill ports the LaTeX content into a pandoc-compatible
  math template (math-basic.tex) and then runs pandoc to produce the .docx output.
  Trigger on ANY mention of converting .tex to .docx, "latex to word", "pandoc from tex",
  or when a .tex file is uploaded and a Word/docx output is desired — even if the user
  just says "convert this to Word" while a .tex file is present.
---

# LaTeX → Word (DOCX) via math-basic.tex Template

Convert any `.tex` file to `.docx` by porting its content into the `math-basic.tex`
pandoc-compatible template, then running pandoc.

---

## Overview of the workflow

1. **Read** the input `.tex` file.
2. **Port** its content into the `math-basic.tex` template (bundled in `assets/`).
3. **Write** the merged file to the working directory as `math-basic.tex`.
4. **Run pandoc** to convert to `.docx`.
5. **Present** the output `.docx` to the user.

---

## Step 1 — Locate the input file

The uploaded `.tex` file will be under `/mnt/user-data/uploads/`. Find it:

```bash
ls /mnt/user-data/uploads/*.tex
```

Read it with the `view` tool.

---

## Step 2 — Understand the template

The template lives at `assets/math-basic.tex` (relative to this SKILL.md).
Its absolute path is: **`/home/claude/skills/latex-to-docx/assets/math-basic.tex`**

The template looks like this (do NOT modify the installed copy):

```latex
\documentclass{article}
\title{TITLE}
\author{NAME}

\usepackage{amsmath}
\usepackage{amsthm}
\usepackage{amssymb}
\usepackage{amsfonts}
\usepackage{braket}

\everymath{\displaystyle}

\usepackage[inline]{enumitem}

\begin{document}

% ← content goes here

\end{document}
```

Key packages already included: `amsmath`, `amsthm`, `amssymb`, `amsfonts`, `braket`, `enumitem`.

---

## Step 3 — Port content into the template

Create a **new** file at `/home/claude/math-basic.tex` (working copy, never edit the asset).

Rules for porting:

| Source element | What to do |
|---|---|
| `\title{...}` | Copy into template's `\title{TITLE}` placeholder |
| `\author{...}` | Copy into template's `\author{NAME}` placeholder |
| `\usepackage{...}` already in template | Skip (already present) |
| `\usepackage{...}` NOT in template | Add after the existing `\usepackage` block |
| `\begin{document}...\end{document}` body | Copy verbatim between the template's `\begin{document}` and `\end{document}` |
| Preamble commands like `\newcommand`, `\DeclareMathOperator`, custom `\theoremstyle` | Add after the `\usepackage` block, before `\begin{document}` |
| `\maketitle` | Keep if present in source body; add it if the source has `\title` / `\author` |

**Critical:** Do NOT add packages that conflict with pandoc (e.g. `fontenc`, `inputenc`, `geometry`, `hyperref` — pandoc injects its own). If the source uses them, omit them silently.

### Minimal ported file shape

```latex
\documentclass{article}
\title{<from source>}
\author{<from source>}

\usepackage{amsmath}
\usepackage{amsthm}
\usepackage{amssymb}
\usepackage{amsfonts}
\usepackage{braket}

\everymath{\displaystyle}

\usepackage[inline]{enumitem}

% Any extra \usepackage or \newcommand from source go here

\begin{document}

% Exact body from source

\end{document}
```

---

## Step 4 — Run pandoc

```bash
cd /home/claude && pandoc -s math-basic.tex -o math-basic.docx
```

Check the exit code. If pandoc fails:

1. Read the error message carefully.
2. Common fixes:
   - **Undefined control sequence** → the source uses a package not in the template; add it.
   - **braket conflict** → rarely an issue with pandoc; ignore braket warnings.
   - **Missing `$`** → math in source was not properly delimited; fix the LaTeX.
3. Fix `math-basic.tex` and retry.

---

## Step 5 — Copy output and present

```bash
cp /home/claude/math-basic.docx /mnt/user-data/outputs/math-basic.docx
```

Then call `present_files` with `/mnt/user-data/outputs/math-basic.docx`.

---

## Notes & edge cases

- **No `\title` / `\author` in source**: leave the template placeholders as `TITLE` / `NAME`.
- **Source already uses `math-basic.tex` as its base**: still go through the porting step to ensure cleanliness.
- **Multiple `.tex` files uploaded**: ask the user which one is the primary file to convert.
- **Encoding**: pandoc handles UTF-8 fine; no need for `inputenc`.
- **`\everymath{\displaystyle}`** is already in the template; do not duplicate.
