# Print Styling & Page Break Architecture

Guidelines for professional A4 / Letter page layout and preventing unwanted blank spaces.

---

## 1. Primary Antipatterns (Root Causes of Blank Voids)

### Antipattern 1: `break-inside: avoid` on Macro Containers
Applying `break-inside: avoid;` to an entire section, scene, or multi-paragraph wrapper taller than 10–12 cm forces the print engine to push the **entire container** to the next page whenever it cannot fit the remainder of the current page.
* **Symptom:** 50–80% of the previous page is left completely blank.
* **Solution:** Apply `break-inside: avoid;` **only to atomic elements** (a single shot card, an individual speech block, a table, a code snippet). Allow long sections to flow naturally across page boundaries.

### Antipattern 2: Arbitrary Hard Page Breaks (`page-break`)
Manually inserting `<div class="page-break"></div>` based on editor assumptions breaks down across different zoom levels, fonts, or viewport sizes.
* **Symptom:** Pages abruptly terminate after a few lines.
* **Solution:** Eliminate arbitrary manual breaks. Rely on CSS flow and `break-after: avoid;` on headings. Use manual page breaks only between distinct major parts (e.g. Acts or Chapters) when the preceding page is already mostly filled.

### Antipattern 3: Double Margin Inflation
Setting `@page { margin: 18mm; }` while also having `body { padding: 24px; }` causes margin stacking, consuming up to 50mm of printable vertical space per sheet.
* **Solution:** Set `body { margin: 0; padding: 0; }` and control margins strictly via `@page { margin: 10mm 14mm 10mm 14mm; }`.

---

## 2. Core CSS Print Rules

```css
@page {
  size: A4 portrait;
  margin: 11mm 14mm 11mm 14mm; /* Compact, balanced margins */
}

@media print {
  body {
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  /* Prevent orphaned headings */
  h1, h2, h3, h4, h5, h6 {
    page-break-after: avoid;
    break-after: avoid;
  }
  /* Atomic element protection */
  table, tr, pre, blockquote, .card, .callout {
    page-break-inside: avoid;
    break-inside: avoid;
  }
  /* Repeat headers on multi-page tables */
  thead {
    display: table-header-group;
  }
}
```

---

## 3. Density Benchmarks (Lines per A4 Page)

* **Screenplay / Dialogue (`Courier New`, 9.5–10pt):** 36–42 lines per page. Character speeches indented `20–25mm`.
* **Shot List / Call Sheet (`Sans-Serif`, 9pt):** 6–8 shot cards per page. Inner padding `6px 10px`, card margin `6px`.
* **Technical Spec / Report (`Sans-serif`, 9.5pt):** 38–44 lines per page. Tables and code blocks protected from splitting.
