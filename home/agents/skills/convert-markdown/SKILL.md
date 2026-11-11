---
name: convert-markdown
description: >-
  Universal Markdown converter and print optimizer. Takes Markdown (.md) as input and converts it into
  publication-quality PDF, Word (.docx), standalone HTML, or sanitized/print-styled Markdown.
  The agent intelligently deduces styling from document content, confirms typography and target formats
  with the user, and compiles clean outputs without orphaned headers, awkward page splits, or empty spaces.
---

# Convert Markdown — Universal Multi-Format Converter

Clean, format, and compile any Markdown document into publication-ready formats:
* **PDF**: Print-optimized for A4 / Letter without awkward page splits, orphaned headers, or empty spaces.
* **DOCX (Word)**: Native Microsoft Word document for client reviews, redlining, and track changes.
* **HTML**: Self-contained single-file document with inline styling for browser viewing and sharing.
* **MD**: Sanitized Markdown with embedded print CSS for direct `Cmd + P` printing in editors.

---

## 1. Agent Workflow Protocol

When the user asks to format or convert a Markdown document:

### Step 1: Analyze Document Structure & Domain
Inspect the document's vocabulary, structure, and recurring elements:
* **Screenplay / Play / Dialogue:** Uppercase character names, parentheticals, scene sluglines (`INT./EXT.`).
* **Shot List / Checklist / Call Sheet:** Numbered shots/items, camera parameters, checkboxes `[ ]`.
* **Technical Spec / Report / Guide:** Tables, code blocks, parameter lists, architecture diagrams.
* **Article / Essay / Book / Longform:** Prose paragraphs, blockquotes, author notes, section dividers.
* **Executive Summary / Proposal:** Bulleted findings, callout badges, summary cards.

---

### Step 2: Formulate Recommendation & Confirm with User
**Never apply styling or format silently.** Propose an informed recommendation and ask for user confirmation (via `ask_question` or multiple-choice prompt).

**Question Pattern:**
> "I analyzed the document content. Based on its structure, it appears to be a **[Document Type]**.  
> **Proposed Styling ([Preset Name]):**  
> • Typography: *[e.g., Courier New monospaced / Inter clean sans-serif / Georgia editorial serif]*  
> • Page Layout: *[e.g., compact 10mm margins / standard 14mm margins]*  
> • Elements: *[e.g., indented dialogue blocks / bordered shot cards with checkboxes / highlighted tables]*  
> • Target Format: *[PDF / Word DOCX / HTML / All]*  
> 
> Do you agree with this setup, or would you prefer a different style or format?"

**Options:**
1. `(Recommended) [Suggested Style] -> PDF (A4)`
2. `[Suggested Style] -> Word DOCX (for editing)`
3. `[Suggested Style] -> All formats (PDF + DOCX + HTML)`
4. `Customize manually (specify custom font, margins, or format)`

---

### Step 3: Execute Conversion
Upon user confirmation, execute the CLI utility located at `scripts/convert.js` within this skill directory (e.g. `~/.agents/skills/convert-markdown/scripts/convert.js` or `<skill-dir>/scripts/convert.js`). If `<skill-dir>/scripts/node_modules` is missing, run `npm --prefix <skill-dir>/scripts ci` once first:

```bash
# Specific format:
node <skill-dir>/scripts/convert.js "input.md" --to pdf --style <preset>
node <skill-dir>/scripts/convert.js "input.md" --to docx --style <preset>
node <skill-dir>/scripts/convert.js "input.md" --to html --style <preset>

# All formats simultaneously:
node <skill-dir>/scripts/convert.js "input.md" --to all --style <preset>
```

---

### Step 4: Quality & Pagination Verification
* Verify generated page count and text distribution.
* Ensure no trailing pages with only 1–2 orphaned lines.
* Ensure headings never appear alone at the bottom of a page (`break-after: avoid`).
* Ensure tables, code blocks, and shot cards do not split awkwardly across pages.

---

## 2. CLI Converter Reference (`convert.js`)

Located at `scripts/convert.js`. Runs standalone with zero heavy external dependencies.

```bash
# Auto-detect target format by output extension:
node convert.js doc.md output.pdf     # Generates PDF
node convert.js doc.md output.docx    # Generates Word (.docx)
node convert.js doc.md output.html    # Generates standalone HTML

# Explicit format flag (--to):
node convert.js doc.md --to pdf
node convert.js doc.md --to docx
node convert.js doc.md --to html
node convert.js doc.md --to all       # Compiles PDF, DOCX, and HTML in one pass

# Style presets (--style):
#   modern     Clean sans-serif (Inter, system-ui) for specs, docs, reports
#   serif      Editorial serif (Georgia, Times) for essays, articles, books
#   mono       Technical monospace for code, configs, system logs
#   screenplay Cinematic typewriter format (Courier New, indented dialogues)
#   shotlist   Card-based layout with borders and checkboxes [ ] for production plans
node convert.js report.md --style modern
node convert.js article.md --style serif
node convert.js script.md --style screenplay

# Optional enhancements:
#   --cover             Generate clean title/cover page from first H1
#   --watermark <text>  Add diagonal watermark (e.g. "DRAFT", "CONFIDENTIAL")
#   --page-numbers      Include running "Page X / Y" footer (default: on)
#   --margin            standard (14mm), compact (10mm), wide (20mm)
#   --page-size         a4 (default) or letter
```

---

## 3. Essential Print & Pagination Rules

1. **Avoid `break-inside: avoid` on large containers**: Never place it on full chapters, sections, or multi-paragraph divs. Browsers will push the entire container to the next page, leaving 50–80% white voids.
2. **Protect only atomic elements**:
   * Tables and table rows (`table, tr { break-inside: avoid; }`)
   * Code blocks (`pre { break-inside: avoid; }`)
   * Blockquotes and dialogue lines (`blockquote { break-inside: avoid; }`)
   * Cards and callouts (`.card, .callout { break-inside: avoid; }`)
   * Images (`img, figure { break-inside: avoid; }`)
3. **Prevent orphaned headings**: Always enforce `h1, h2, h3, h4, h5, h6 { break-after: avoid; page-break-after: avoid; }`.
4. **Repeat table headers**: Set `thead { display: table-header-group; }` so long tables carry column titles across pages.
5. **Zero-out body padding**: Manage page geometry strictly inside `@page { margin: ...; }` to prevent double-margin inflation.

See [A4 Print Styles Reference](./references/a4-print-styles.md) and [Styling Guide](./references/markdown-styling-guide.md).
