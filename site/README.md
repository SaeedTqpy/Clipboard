# Clipboard Experience — immersive website

**Source:** `site/` on the main branch.  
**Publication:** the root of the dedicated `gh-pages` branch.  
**Live GitHub Pages URL:** https://saeedtqpy.github.io/Clipboard/ (Pages deployment verified 2026-11-13)

## Concept

An original **Memory Atlas**: the copied fragments of a day become tangible, floating, glowing objects. One persistent Three.js world responds to page-scroll progress and pointer movement. The product is introduced through an editorial seven-scene narrative rather than a traditional screenshot-and-feature grid.

References informed *interaction principles*, not copied designs:
- Lusion (physical-looking, pointer-reactive 3D): https://lusion.co/
- Bruno Simon / Codrops (Three.js background synced to document scroll): https://tympanus.net/codrops/2022/01/05/crafting-scroll-based-animations-in-three-js/
- Codrops 2026 scroll-revealed galleries: https://tympanus.net/codrops/2026/02/02/building-a-scroll-revealed-webgl-gallery-with-gsap-three-js-astro-and-barba-js/
- Lenis scroll smoothing: https://lenis.dev/

The illustrations on 3D cards are **conceptual**. They are deliberately labeled as such, and must not be passed off as screenshots of the desktop app.

## Architecture

- Semantic HTML: `index.html`
- Original responsive styling and CSS 3D fallback: `styles.css`
- DOM scroll choreography, optional GSAP/Lenis and accessible memory selector: `main.js`
- Persistent Three.js world, procedurally modeled rounded cards, procedural memory textures, custom Fresnel shader and light ribbons: `world.js`
- Original vector favicon, Open Graph art, robots and sitemap.
- Zero bundler, zero npm install, zero build command. Files are ready to serve on GitHub Pages.

### Version-pinned browser dependencies

The following libraries load via public CDNs:
- Three.js `0.181.0` — ES module via jsDelivr import map
- GSAP `3.13.0` and ScrollTrigger — optional progressive enhancement
- Lenis `1.3.27` — optional smooth-scrolling enhancement
- Google Fonts: Space Grotesk, Instrument Serif, DM Sans, DM Mono

**There is no analytics and no account collection.** The above CDNs/font hosts do receive ordinary browser asset requests. If zero third-party asset requests are required, vendor and self-host all dependencies in a separate release task.

## Performance and accessibility

- Responsive artwork includes a **CSS-only 3D scene fallback** if WebGL 2, external scripts or network access are unavailable.
- WebGL is **not initialized** on narrow screens, Save-Data connections or when the visitor chooses Reduced Motion.
- The WebGL renderer caps device pixel ratio and rendering frame rate; scene uses re-used geometry and bounded particle count.
- Geometry and stylized content are procedurally generated in the browser; no heavy models, texture packs or remote 3D assets.
- All narrative content remains selectable semantic DOM text with native anchor navigation.
- Native focus outlines, keyboard-operable selection controls, ARIA for mobile navigation, and an active text readout.
- Honor `prefers-reduced-motion` and `prefers-contrast`; motion libraries are optional and never gate critical content.
- Some Three.js features still need performance and accessibility testing on **real Safari, mobile devices, and macOS**.

## Run locally

No Xcode, Apple Developer Account, Node.js or npm required. Any static HTTP server will work.

```bash
cd site
python3 -m http.server 8000
# Open http://localhost:8000/
```

The page depends on online CDNs for Three.js, fonts and optional animation libraries; if offline, the designed CSS fallback still works.

## Publish with GitHub Pages (no repository CI required)

After the `gh-pages` branch has been created:
1. In **Repository Settings → Pages**, choose **Deploy from a branch**.
2. Choose **gh-pages** and **/(root)**, then Save.
3. GitHub's Pages service will publish to the project URL once configured.
4. Future updates can be copied from `site/` into the `gh-pages` branch using `bash scripts/deploy-pages.sh` from the repository root. That script does not trigger macOS builds.
5. **Do not enable push-triggered macOS CI.** The desktop app's workflow stays manual-only.

GitHub Pages' own publication mechanism may display a Pages deployment workflow. That is separate from the project's manually triggered macOS compilation workflow.

## Security

- No data collection, login form or pasteboard access on the website.
- External links use `rel="noopener noreferrer"`.
- The site's download CTA links to the **validated, unsigned developer preview artifact** rather than claiming a notarized release.
- Do not add interactive demo code that automatically reads the visitor's actual system clipboard.
- For the real macOS app's privacy constraints, see [SECURITY.md](../SECURITY.md).

## Production follow-ups

Perform a full visual QA pass in Chrome, Firefox, Safari/macOS and mobile Safari; validate 3D motion and low-power fallback on actual devices, run Lighthouse and accessibility audits, and consider self-hosting third-party scripts with Subresource Integrity or a bundling step for hardened releases.
