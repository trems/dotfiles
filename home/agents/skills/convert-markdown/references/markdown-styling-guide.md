# Universal Markdown Print Styling Guide

Best practices for preparing any Markdown document (reports, specifications, articles, notes, proposals) for professional print and multi-format export.

---

## 1. Structural Elements & Styling

### Headings (`h1`–`h4`)
- Must be semantic and never orphaned at the bottom of a page.
- CSS Rule: `h1, h2, h3, h4 { break-after: avoid; page-break-after: avoid; }`.
- Recommended print sizes:
  - `h1`: 1.4–1.5em (document title with bottom rule)
  - `h2`: 1.15–1.2em (primary sections with light divider)
  - `h3`: 1.05em (subsections)
  - `h4`: 0.95–1.0em

### Tables (`table`)
- Use compact padding and subtle header backgrounds (`th { background: #f3f4f6; font-weight: 600; }`).
- Multi-page table support:
  ```css
  thead { display: table-header-group; }
  tr { page-break-inside: avoid; break-inside: avoid; }
  ```
- Compact tables should be protected entirely: `table { page-break-inside: avoid; }`.

### Code Blocks (`pre`, `code`)
- Monospace font stack (`ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace`).
- Light background `#f8fafc` with subtle border `1px solid #e2e8f0`.
- Protection from awkward splits: `pre { page-break-inside: avoid; break-inside: avoid; }`.

### Quotes and Callouts (`blockquote`, `.callout`, `.card`)
- `blockquote`: Left accent border `3px solid #94a3b8`, left padding `12px`.
- `.callout` / `.card`: 4px rounded border, soft background, split protection.

---

## 2. Typography & Density Guidelines

| Parameter | Recommended for A4 |
| :--- | :--- |
| **Body Font Stack** | `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto` (sans) or `Georgia, Times` (serif) |
| **Base Font Size** | 9.5–10pt for continuous reading |
| **Line Height (`line-height`)** | 1.4–1.45 (balanced air without inflating vertical height) |
| **Page Margins (`@page`)** | `12mm 15mm 12mm 15mm` (standard), `10mm 12mm` (compact) |
| **Paragraph Margins** | `margin: 4px 0 6px 0;` (prevents vertical space bloat) |

---

## 3. Pre-Conversion Sanitization Checklist

Before compiling to PDF, Word, or HTML:
1. Fix mangled bold/italic markup (e.g. `** **`, `**:**`, `* *`).
2. Remove empty headers (e.g. `##   `).
3. Normalize excessive consecutive empty lines (`\n\n\n` -> `\n\n`).
4. Ensure tables have valid CommonMark/GFM syntax with proper separator lines.
