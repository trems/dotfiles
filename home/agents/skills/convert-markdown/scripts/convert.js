#!/usr/bin/env node

/**
 * convert.js — Universal Markdown Converter
 * Input: Markdown (.md)
 * Output: PDF, DOCX (Word), HTML (Standalone), or Cleaned MD
 * Part of the convert-markdown agent skill.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function ensureDependencies() {
  const scriptsDir = __dirname;
  const markedDir = path.join(scriptsDir, 'node_modules', 'marked');
  if (!fs.existsSync(markedDir)) {
    try {
      console.log('convert-markdown: Installing required npm dependencies (marked, html-to-docx)...');
      execSync('npm install --no-audit --no-fund', { cwd: scriptsDir, stdio: 'inherit' });
    } catch (e) {
      console.warn('Warning: Automatic npm install failed:', e.message);
    }
  }
}

ensureDependencies();

let marked;
try {
  marked = require(path.join(__dirname, 'node_modules', 'marked')).marked;
} catch (e) {
  try {
    marked = require('marked').marked;
  } catch (err) {
    console.error('Error: "marked" package is required. Run: npm install inside ' + __dirname);
    process.exit(1);
  }
}

let HTMLtoDOCX;
try {
  HTMLtoDOCX = require(path.join(__dirname, 'node_modules', 'html-to-docx'));
} catch (e) {
  try {
    HTMLtoDOCX = require('html-to-docx');
  } catch (err) {
    // DOCX will warn if requested
  }
}

// -------------------------------------------------------------
// CLI Argument Parsing
// -------------------------------------------------------------
const args = process.argv.slice(2);

if (args.length === 0 || args.includes('-h') || args.includes('--help')) {
  console.log(`
convert-markdown CLI — Convert Markdown into PDF, DOCX, HTML, or Cleaned MD

Usage:
  node convert.js <input.md> [output-file] [options]

Target Formats (--to or inferred from output extension):
  --to pdf              Compile to print-ready PDF (default)
  --to docx             Compile to Microsoft Word (.docx)
  --to html             Compile to self-contained, styled HTML (.html)
  --to md               Save cleaned & styled Markdown (.md)
  --to all              Generate PDF, DOCX, and HTML simultaneously

Style & Typography:
  --style <name>        Style preset: 'modern' (default), 'serif', 'mono', 'screenplay', 'shotlist'
  --page-size <size>    Page size: 'a4' (default), 'letter'
  --margin <margin>     Margins: 'standard' (14mm, default), 'compact' (10mm), 'wide' (20mm)

Document Elements:
  --cover               Generate a clean title/cover page from first H1
  --watermark <text>    Add subtle diagonal watermark (e.g. "ЧЕРНОВИК", "DRAFT", "CONFIDENTIAL")
  --page-numbers        Add "стр. X из Y" running footer (default: on)
  --no-page-numbers     Suppress page numbers in footer
  --custom-css <path>   Inject additional custom CSS rules from file
  -h, --help            Show this help message

Examples:
  node convert.js doc.md                       # Generates doc (A4).pdf
  node convert.js doc.md --to docx             # Generates doc.docx
  node convert.js doc.md --to html             # Generates doc.html
  node convert.js doc.md --to all              # Generates PDF, DOCX, and HTML
  node convert.js doc.md "Custom.docx"         # Auto-detects DOCX from extension
  node convert.js script.md --style screenplay # Screenplay formatting
`);
  process.exit(0);
}

let inputFile = null;
let explicitOutputFile = null;
let targetFormats = [];
let stylePreset = 'modern';
let pageSize = 'a4';
let marginPreset = 'standard';
let showPageNumbers = true;
let watermarkText = null;
let addCover = false;
let customCssPath = null;

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--to' || arg === '-t') {
    const val = (args[++i] || 'pdf').toLowerCase();
    if (val === 'all') {
      targetFormats = ['pdf', 'docx', 'html'];
    } else {
      targetFormats.push(val);
    }
  } else if (arg === '--style' || arg === '--theme' || arg === '-s') {
    stylePreset = (args[++i] || 'modern').toLowerCase();
  } else if (arg === '--page-size') {
    pageSize = (args[++i] || 'a4').toLowerCase();
  } else if (arg === '--margin') {
    marginPreset = args[++i] || 'standard';
  } else if (arg === '--page-numbers') {
    showPageNumbers = true;
  } else if (arg === '--no-page-numbers') {
    showPageNumbers = false;
  } else if (arg === '--watermark') {
    watermarkText = args[++i] || 'DRAFT';
  } else if (arg === '--cover') {
    addCover = true;
  } else if (arg === '--custom-css') {
    customCssPath = args[++i];
  } else if (!arg.startsWith('-')) {
    if (!inputFile) {
      inputFile = arg;
    } else if (!explicitOutputFile) {
      explicitOutputFile = arg;
    }
  }
}

if (!inputFile) {
  console.error('Error: No input markdown file specified.');
  process.exit(1);
}

if (!fs.existsSync(inputFile)) {
  console.error(`Error: File not found: ${inputFile}`);
  process.exit(1);
}

const parsedInput = path.parse(inputFile);

// Detect format from explicit output file extension if specified
if (explicitOutputFile) {
  const ext = path.extname(explicitOutputFile).toLowerCase().replace('.', '');
  if (['pdf', 'docx', 'html', 'md'].includes(ext)) {
    if (!targetFormats.includes(ext)) {
      targetFormats.push(ext);
    }
  }
}

// Default target format is PDF
if (targetFormats.length === 0) {
  targetFormats = ['pdf'];
}

// -------------------------------------------------------------
// Browser Detection (for PDF generation)
// -------------------------------------------------------------
function findChromium() {
  const candidates = [
    '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium'
  ];

  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }

  try {
    const found = execSync('which brave-browser || which google-chrome || which chromium', { stdio: 'pipe' }).toString().trim();
    if (found && fs.existsSync(found)) return found;
  } catch (e) {}

  return null;
}

// -------------------------------------------------------------
// Style Generator
// -------------------------------------------------------------
function buildStylesheet(preset, size, marginMode, pageNums) {
  let marginCss = '12mm 15mm 12mm 15mm';
  if (marginMode === 'compact') {
    marginCss = '10mm 12mm 10mm 12mm';
  } else if (marginMode === 'wide') {
    marginCss = '18mm 20mm 18mm 20mm';
  }

  const pageRule = size === 'letter' ? `size: letter portrait;` : `size: A4 portrait;`;

  let extraCss = '';
  if (customCssPath && fs.existsSync(customCssPath)) {
    extraCss = fs.readFileSync(customCssPath, 'utf8');
  }

  const pageNumCss = pageNums ? `
    @bottom-center {
      content: counter(page) " / " counter(pages);
      font-size: 8pt;
      color: #94a3b8;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }` : '';

  if (preset === 'screenplay') {
    return `<style>
  @page { ${pageRule} margin: 11mm 15mm 11mm 15mm; ${pageNumCss} }
  @media print {
    body { font-size: 9.5pt; line-height: 1.32; color: #111; background: #fff; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    h2 { page-break-after: avoid; break-after: avoid; }
    blockquote { page-break-inside: avoid; break-inside: avoid; }
  }
  body { font-family: "Courier New", Courier, monospace; font-size: 9.5pt; line-height: 1.32; color: #1a1a1a; margin: 0; padding: 0; }
  h1 { text-align: center; font-size: 1.25em; text-transform: uppercase; letter-spacing: 1.5px; border-bottom: 1.5px solid #222; padding-bottom: 3px; margin: 0 0 8px 0; }
  h2 { font-size: 9.8pt; text-transform: uppercase; letter-spacing: 0.5px; background: #f3f4f6; padding: 3px 6px; border-left: 3px solid #111; margin: 8px 0 3px 0; page-break-after: avoid; break-after: avoid; }
  p { margin: 3px 0; text-align: justify; }
  .cue { font-weight: bold; color: #111; margin: 4px 0 2px 0; text-transform: uppercase; font-size: 8.8pt; }
  blockquote { margin: 3px 0 4px 20mm; max-width: 125mm; border-left: 2px solid #4b5563; padding: 2px 8px; background: #f9fafb; page-break-inside: avoid; break-inside: avoid; font-style: normal; }
  blockquote p { margin: 1px 0; }
  blockquote strong { display: block; text-transform: uppercase; letter-spacing: 0.5px; color: #111827; margin-bottom: 1px; }
  blockquote em { display: block; font-style: italic; color: #4b5563; margin-bottom: 1px; }
  hr { border: 0; border-top: 1px solid #e5e7eb; margin: 5px 0; }
  ${extraCss}
</style>`;
  }

  if (preset === 'shotlist') {
    return `<style>
  @page { ${pageRule} margin: 10mm 12mm 10mm 12mm; ${pageNumCss} }
  @media print {
    body { font-size: 9pt; line-height: 1.35; color: #111; background: #fff; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    .shot-card, .card { page-break-inside: avoid; break-inside: avoid; }
    h2 { page-break-after: avoid; break-after: avoid; }
  }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #1f2937; line-height: 1.35; margin: 0; padding: 0; }
  h1 { text-align: center; font-size: 1.35em; text-transform: uppercase; letter-spacing: 1px; border-bottom: 1.5px solid #111827; padding-bottom: 4px; margin: 0 0 8px 0; color: #111827; }
  h2 { font-size: 10.5pt; text-transform: uppercase; background: #e5e7eb; padding: 4px 8px; border-left: 4px solid #1f2937; margin-top: 10px; margin-bottom: 6px; page-break-after: avoid; break-after: avoid; border-radius: 2px; color: #111827; }
  .shot-card, .card { border: 1px solid #d1d5db; border-left: 3px solid #2563eb; background: #f9fafb; border-radius: 3px; padding: 6px 10px; margin-bottom: 6px; page-break-inside: avoid; break-inside: avoid; }
  .shot-card h3, .shot-card h4, .card h3, .card h4 { margin: 0 0 3px 0; font-size: 9.5pt; color: #1e3a8a; font-weight: 700; }
  .shot-card ul, .card ul { margin: 0; padding-left: 16px; }
  .shot-card li, .card li { margin-bottom: 2px; font-size: 8.8pt; }
  strong { color: #111827; }
  hr { border: 0; border-top: 1px solid #e5e7eb; margin: 6px 0; }
  ${extraCss}
</style>`;
  }

  let fontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';
  let headingFamily = fontFamily;
  let codeFamily = 'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace';

  if (preset === 'serif') {
    fontFamily = 'Georgia, Cambria, "Times New Roman", Times, serif';
    headingFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
  } else if (preset === 'mono') {
    fontFamily = codeFamily;
    headingFamily = codeFamily;
  }

  return `<style>
  @page { ${pageRule} margin: ${marginCss}; ${pageNumCss} }
  @media print {
    body { font-size: 9.8pt; line-height: 1.4; color: #111; background: #fff; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    h1, h2, h3, h4, h5, h6 { page-break-after: avoid; break-after: avoid; }
    table, pre, blockquote, figure, .card, .callout, tr { page-break-inside: avoid; break-inside: avoid; }
    thead { display: table-header-group; }
  }
  body { font-family: ${fontFamily}; color: #1f2937; line-height: 1.45; margin: 0; padding: 0; }
  h1, h2, h3, h4, h5, h6 { font-family: ${headingFamily}; color: #111827; margin-top: 14px; margin-bottom: 6px; page-break-after: avoid; break-after: avoid; }
  h1 { font-size: 1.45em; font-weight: 700; border-bottom: 1.5px solid #111827; padding-bottom: 4px; margin-top: 0; margin-bottom: 10px; }
  h2 { font-size: 1.18em; border-bottom: 1px solid #e5e7eb; padding-bottom: 3px; margin-top: 16px; }
  h3 { font-size: 1.05em; }
  h4 { font-size: 0.95em; }
  p, ul, ol { margin: 4px 0 6px 0; }
  li { margin-bottom: 2px; }
  ul, ol { padding-left: 20px; }
  table { width: 100%; border-collapse: collapse; margin: 8px 0; font-size: 9pt; page-break-inside: avoid; break-inside: avoid; }
  th, td { border: 1px solid #d1d5db; padding: 5px 8px; text-align: left; vertical-align: top; }
  th { background: #f3f4f6; font-weight: 600; }
  tr:nth-child(even) td { background: #f9fafb; }
  pre, code { font-family: ${codeFamily}; font-size: 8.8pt; }
  code { background: #f1f5f9; padding: 1px 4px; border-radius: 3px; color: #0f172a; }
  pre { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 4px; padding: 8px 10px; overflow-x: auto; margin: 6px 0; page-break-inside: avoid; break-inside: avoid; }
  pre code { background: transparent; padding: 0; border-radius: 0; }
  blockquote { border-left: 3px solid #94a3b8; margin: 6px 0; padding: 3px 12px; color: #475569; background: #f8fafc; page-break-inside: avoid; break-inside: avoid; }
  blockquote p { margin: 2px 0; }
  .card, .callout { border: 1px solid #e2e8f0; border-radius: 4px; background: #f8fafc; padding: 8px 12px; margin: 8px 0; page-break-inside: avoid; break-inside: avoid; }
  .callout { border-left: 4px solid #2563eb; }
  hr { border: 0; border-top: 1px solid #e5e7eb; margin: 8px 0; }
  img { max-width: 100%; height: auto; page-break-inside: avoid; break-inside: avoid; }
  ${extraCss}
</style>`;
}

// -------------------------------------------------------------
// Markdown Sanitization & Preparation
// -------------------------------------------------------------
const rawContent = fs.readFileSync(inputFile, 'utf8');

let cleanBody = rawContent
  .replace(/<style>[\s\S]*?<\/style>/gi, '')
  .trim()
  .replace(/\*\*\s+\*\*/g, ' ')
  .replace(/\*\*\s*:\s*\*\*/g, ':** ')
  .replace(/([^\s])\*\*:\*\*/g, '$1:** ')
  .replace(/([A-Za-zА-Яа-яЁё0-9])\*\*\s+\*\*/g, '$1 ')
  .replace(/##\s+$/gm, '')
  .replace(/\n{3,}/g, '\n\n');

// Optional cover page
let coverHtml = '';
let docTitle = parsedInput.name;
const matchH1 = cleanBody.match(/^#\s+(.+)$/m);
if (matchH1) {
  docTitle = matchH1[1];
}

if (addCover) {
  coverHtml = `
<div class="cover-page" style="page-break-after: always; display: flex; flex-direction: column; justify-content: center; min-height: 80vh; text-align: center; padding: 40px 20px;">
  <h1 style="font-size: 2.8em; margin-bottom: 16px; border-bottom: none;">${docTitle}</h1>
  <p style="font-size: 1.1em; color: #64748b; margin-top: 8px;">Document prepared for publication</p>
  <div style="margin-top: 40px; font-size: 0.9em; color: #94a3b8;">${new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</div>
</div>
`;
}

// Optional watermark
let watermarkHtml = '';
if (watermarkText) {
  watermarkHtml = `
<div class="watermark" style="position: fixed; top: 45%; left: 15%; transform: rotate(-35deg); font-size: 6rem; color: rgba(0,0,0,0.06); font-weight: 900; letter-spacing: 4px; pointer-events: none; z-index: 9999; text-transform: uppercase;">
  ${watermarkText}
</div>`;
}

const stylesheet = buildStylesheet(stylePreset, pageSize, marginPreset, showPageNumbers);
const formattedMarkdown = `${stylesheet}\n\n${cleanBody}\n`;
const parsedHtmlBody = marked.parse(formattedMarkdown);

const fullHtmlDocument = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${docTitle}</title>
${stylesheet}
</head>
<body style="padding: 20px; max-width: 860px; margin: 0 auto;">
${watermarkHtml}
${coverHtml}
${parsedHtmlBody}
</body>
</html>`;

// -------------------------------------------------------------
// Conversion Execution (Async)
// -------------------------------------------------------------
(async () => {
  for (const fmt of targetFormats) {
    if (fmt === 'md') {
      const targetMd = explicitOutputFile && explicitOutputFile.endsWith('.md')
        ? explicitOutputFile
        : path.join(parsedInput.dir, `${parsedInput.name}.md`);
      fs.writeFileSync(targetMd, formattedMarkdown, 'utf8');
      console.log(`✓ Cleaned Markdown saved: ${targetMd}`);
    }

    if (fmt === 'html') {
      const targetHtml = explicitOutputFile && explicitOutputFile.endsWith('.html')
        ? explicitOutputFile
        : path.join(parsedInput.dir, `${parsedInput.name}.html`);
      fs.writeFileSync(targetHtml, fullHtmlDocument, 'utf8');
      console.log(`✓ Standalone HTML saved: ${targetHtml} (${fs.statSync(targetHtml).size} bytes)`);
    }

    if (fmt === 'docx') {
      if (!HTMLtoDOCX) {
        console.error('Error: "html-to-docx" module is required for Word export.');
        continue;
      }
      const targetDocx = explicitOutputFile && explicitOutputFile.endsWith('.docx')
        ? explicitOutputFile
        : path.join(parsedInput.dir, `${parsedInput.name}.docx`);

      try {
        const docxBuffer = await HTMLtoDOCX(fullHtmlDocument, null, {
          table: { row: { cantSplit: true } },
          footer: showPageNumbers,
          pageNumber: showPageNumbers,
          font: stylePreset === 'serif' ? 'Georgia' : stylePreset === 'mono' ? 'Courier New' : 'Calibri'
        });
        fs.writeFileSync(targetDocx, docxBuffer);
        console.log(`✓ Microsoft Word saved: ${targetDocx} (${fs.statSync(targetDocx).size} bytes)`);
      } catch (err) {
        console.error(`Error generating DOCX: ${err.message}`);
      }
    }

    if (fmt === 'pdf') {
      const browserPath = findChromium();
      if (!browserPath) {
        console.error('Error: No Chromium-based browser found (Brave, Chrome, Edge, Chromium).');
        continue;
      }
      const targetPdf = explicitOutputFile && explicitOutputFile.endsWith('.pdf')
        ? explicitOutputFile
        : path.join(parsedInput.dir, `${parsedInput.name} (${pageSize.toUpperCase()}).pdf`);

      const tmpHtml = path.join('/tmp', `cv_${Date.now()}_${Math.random().toString(36).substring(7)}.html`);
      fs.writeFileSync(tmpHtml, fullHtmlDocument, 'utf8');

      try {
        const cmd = `"${browserPath}" --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf="${targetPdf}" "${tmpHtml}"`;
        execSync(cmd, { stdio: 'pipe' });
        console.log(`✓ Print-ready PDF saved: ${targetPdf} (${fs.statSync(targetPdf).size} bytes)`);
      } catch (err) {
        console.error(`Error generating PDF: ${err.message}`);
      } finally {
        if (fs.existsSync(tmpHtml)) {
          fs.unlinkSync(tmpHtml);
        }
      }
    }
  }
})();
