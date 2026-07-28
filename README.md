# CV — Yuval Gabay

Interactive CV, built for the [Bavaria Israel Partnership Accelerator](https://bip-accelerator.com/) 2026 application.

**Live:** https://yuvalgabay20.github.io/cv/
**PDF:** [Yuval-Gabay-CV.pdf](docs/Yuval-Gabay-CV.pdf)

## How it is put together

- `index.html` — the whole page: markup, styles and script in one file, no dependencies and no build step for the content itself.
- `build-site.ps1` — wraps `index.html` in a full HTML document and writes `docs/`, which is what GitHub Pages serves.
- `docs/` — generated. Do not edit by hand; edit `index.html` and run the script.

The same file produces both the screen version and the PDF: the print stylesheet
rearranges it into a two-page A4 document, so the two can never drift apart.

```powershell
powershell -ExecutionPolicy Bypass -File build-site.ps1
```

To regenerate the PDF, open the page and print to PDF (A4, no headers or footers).

## Notes

- The background is a wireframe panel turning under a scan pass — a nod to two years
  and eight months of non-destructive testing on aircraft. Rendered on a canvas with
  hand-written projection maths; no 3D library.
- Light and dark are both first-class; the page follows the reader's system setting.
- The page is `noindex`: reachable by anyone with the link, kept out of search results.
