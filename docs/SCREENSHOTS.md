# Real macOS screenshots for README

## Why the gallery is not filled with mockups

Clipboard has a compiled macOS app, but the GitHub-hosted build does not produce a verified screenshot of its live interface. **We do not advertise generated mockups or invented UI as genuine screenshots.**

A screenshot must come from a real running build on macOS, with **synthetic clipboard content only**. Personal names, passwords, tokens, browsing data, file paths, notifications or confidential desktop windows must not be visible.

## Capture without Xcode

1. Install the [validated unsigned build](https://github.com/SaeedTqpy/Clipboard/actions/runs/43389410106) on your Mac.
2. Prepare harmless sample entries, for example: `Clipboard demo 001`, `https://example.org/demo`, and `sample snippet — hello world`.
3. Open Clipboard via `⌘⇧V`. Verify the actual window looks correct before capturing it.
4. Clone or update the repository in Terminal:

   ```bash
   git clone https://github.com/SaeedTqpy/Clipboard.git
   cd Clipboard
   bash scripts/capture-readme-screenshots.sh
   ```

5. The script prompts you to select the **History**, **Search**, and **Settings** windows using macOS `screencapture`. It needs Screen Recording permission if your macOS installation requests it.
6. The generated files are placed at:
   - `docs/screenshots/history.png`
   - `docs/screenshots/search.png`
   - `docs/screenshots/settings.png`
7. The script updates **both** `README.md` and `README.fa.md` to embed those actual PNG files. Inspect **each image** before publishing.
8. If and only if every screenshot is free of sensitive data, commit the PNGs and README changes manually:

   ```bash
   git add README.md README.fa.md docs/screenshots/
   git commit -m "docs: add real macOS interface screenshots"
   git push origin main
   ```

## Screenshot quality requirements

- Capture the **actual Clipboard app**, not a concept render or Xcode preview.
- Use a consistent appearance (dark or light). Show the Liquid Glass effect on macOS 26 if present; do not label a macOS 15 fallback as Tahoe Liquid Glass.
- Prefer crisp high-resolution PNGs at native Retina scale and keep window borders/shadows consistent.
- Include meaningful synthetic items and a clear example of search results.
- For settings, show capture controls and privacy options with **fake bundle IDs only**.
- Do not crop away important controls or obscure failures. If a window looks broken, fix the app before publishing the screenshot.
- Review screenshots with Preview before committing. GitHub is a public repository.

## Files and README gallery

The README contains bounded markers `<!-- SCREENSHOTS:START -->` and `<!-- SCREENSHOTS:END -->`. The script replaces **only the content between those markers** with a three-column screenshot gallery after the PNGs have been captured.

No Xcode, Apple Developer membership or GitHub Actions minutes are needed for screenshot capture.
