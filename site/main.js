/**
 * Clipboard Experience / scroll director
 * A single native-scroll document orchestrates the 3D world and editorial text.
 * No analytics, cookies, content collection, or page-navigation hijacking.
 */
const root = document.documentElement;
const body = document.body;
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const compactViewport = window.matchMedia("(max-width: 760px)");
const slowConnection = Boolean(navigator.connection?.saveData);
const sections = [...document.querySelectorAll("[data-scene]")];
const storySteps = [...document.querySelectorAll(".journey__step")];
const memoryButtons = [...document.querySelectorAll(".memory-option")];
const memoryLabels = ["THE THOUGHT", "THE SNIPPET", "THE FIND", "THE IMAGE"];
const worldContainer = document.querySelector("#cinema");
const navToggle = document.querySelector("#nav-toggle");
const mobileMenu = document.querySelector("#mobile-menu");
const header = document.querySelector("#header");
const progress = document.querySelector("#progress-line");
const readout = document.querySelector("#memory-label");
const storyRail = document.querySelector("#journey-rail");
const chapterCount = document.querySelector("#chapter-number");

document.querySelector("#year").textContent = String(new Date().getFullYear());
let memoryIndex = 0;
let world = null;
let lastTime = 0;
let targetPhase = 0;
let activePhase = 0;
let storyPhase = 0;
let scrollFraction = 0;
const pointer = { x: 0, y: 0 };
const prefersQuiet = () => reducedMotion.matches;

function setMenu(open) {
  navToggle.setAttribute("aria-expanded", String(open));
  mobileMenu.hidden = !open;
  body.classList.toggle("menu-open", open);
  if (open) mobileMenu.querySelector("a")?.focus();
}
navToggle.addEventListener("click", () => setMenu(navToggle.getAttribute("aria-expanded") !== "true"));
mobileMenu.querySelectorAll("a").forEach((a) => a.addEventListener("click", () => setMenu(false)));
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !mobileMenu.hidden) {
    setMenu(false);
    navToggle.focus();
  }
});

memoryButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const index = Number(button.dataset.memory);
    if (!Number.isInteger(index) || index < 0 || index >= memoryButtons.length) return;
    memoryIndex = index;
    memoryButtons.forEach((entry, i) => {
      entry.classList.toggle("is-selected", i === index);
      entry.setAttribute("aria-pressed", String(i === index));
    });
    readout.textContent = memoryLabels[index];
    world?.setMemory(index);
  });
});

if (window.matchMedia("(pointer:fine)").matches && !prefersQuiet()) {
  window.addEventListener("pointermove", (event) => {
    pointer.x = (event.clientX / window.innerWidth - 0.5) * 2;
    pointer.y = (event.clientY / window.innerHeight - 0.5) * 2;
    root.style.setProperty("--cursor-x", pointer.x.toFixed(3));
    root.style.setProperty("--cursor-y", pointer.y.toFixed(3));
  }, { passive: true });
}

// Progressive enhancement only: if either CDN dependency cannot load,
// users keep normal browser scrolling, visible type, and the CSS 3D sculpture.
function setupMotion() {
  if (prefersQuiet()) return;
  if (typeof window.Lenis === "function") {
    const lenis = new window.Lenis({
      autoRaf: true,
      duration: 1.12,
      smoothWheel: true,
      anchors: true,
      touchMultiplier: 1.05,
      lerp: 0.105
    });
    window.__clipboardLenis = lenis;
    if (window.ScrollTrigger) lenis.on("scroll", window.ScrollTrigger.update);
  }
  if (window.gsap && window.ScrollTrigger) {
    const { gsap, ScrollTrigger } = window;
    gsap.registerPlugin(ScrollTrigger);
    document.querySelectorAll("[data-animate]").forEach((node) => {
      if (node.closest(".hero")) {
        gsap.fromTo(node, { opacity: 0, y: 37, filter: "blur(8px)" }, {
          opacity: 1, y: 0, filter: "blur(0px)", duration: 1.25, ease: "expo.out",
          delay: node.classList.contains("hero__headline") ? .12 : .22,
          scrollTrigger: { trigger: ".hero", start: "top bottom", once: true }
        });
      } else {
        gsap.fromTo(node, { opacity: .22, y: 75, filter: "blur(6px)" }, {
          opacity: 1, y: 0, filter: "blur(0px)", ease: "none",
          scrollTrigger: {
            trigger: node, start: "top 98%", end: "top 60%", scrub: 1
          }
        });
      }
    });
    document.querySelectorAll(".feature-box").forEach((node, index) => {
      gsap.fromTo(node, { y: 74, opacity: .15 }, {
        y: 0, opacity: 1, duration: .9, ease: "power3.out",
        delay: index * .1, scrollTrigger: { trigger: node, start: "top 90%" }
      });
    });
  }
}
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", setupMotion, { once: true });
} else {
  setupMotion();
}

function interpolateSegment() {
  const midpoint = window.scrollY + window.innerHeight * .52;
  const points = sections.map((section) => section.offsetTop + section.offsetHeight * .5);
  if (!points.length) return 0;
  if (midpoint <= points[0]) return 0;
  for (let i = 0; i < points.length - 1; i++) {
    if (midpoint <= points[i + 1]) {
      return i + (midpoint - points[i]) / Math.max(1, points[i + 1] - points[i]);
    }
  }
  return points.length - 1;
}

function updateScrollState() {
  const maxY = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
  scrollFraction = Math.min(1, Math.max(0, window.scrollY / maxY));
  root.style.setProperty("--progress", scrollFraction.toFixed(4));
  header.classList.toggle("is-scrolled", window.scrollY > 45);

  targetPhase = interpolateSegment();
  const nearest = Math.min(sections.length - 1, Math.max(0, Math.round(targetPhase)));
  const selectedScene = sections[nearest]?.dataset.scene ?? "hero";
  body.dataset.scene = selectedScene;

  // Fixed chapter counter for the user—not a fake progress percentage.
  const chapters = ["hero","concept","interlude","journey","lab","privacy","features","outro"];
  const index = Math.max(0, chapters.indexOf(selectedScene));
  const publicChapter = Math.min(6, Math.max(1, index));
  chapterCount.textContent = String(publicChapter).padStart(2, "0");

  // Scroll-scrubbed chapter progress controls the 3D card separation.
  const journey = document.querySelector("#experience");
  const start = journey.offsetTop + window.innerHeight * .66;
  const end = journey.offsetTop + journey.offsetHeight - window.innerHeight * .5;
  const relative = (window.scrollY - start) / Math.max(1, end - start);
  storyPhase = Math.max(0, Math.min(3, relative * 3));
  storyRail.style.transform = "scaleY(" + Math.min(1, Math.max(0, relative)).toFixed(4) + ")";
  storySteps.forEach((step, i) => {
    const rect = step.getBoundingClientRect();
    step.classList.toggle("is-active", rect.top < window.innerHeight * .68 && rect.bottom > window.innerHeight * .3);
  });
}
window.addEventListener("scroll", updateScrollState, { passive: true });
window.addEventListener("resize", updateScrollState, { passive: true });
updateScrollState();

function frame(ms) {
  const dt = lastTime ? Math.min(0.06, (ms - lastTime) / 1000) : .016;
  lastTime = ms;
  if (!document.hidden) {
    const ease = 1 - Math.exp(-dt * 4.3);
    activePhase += (targetPhase - activePhase) * ease;
    world?.render({
      time: ms * .001,
      dt,
      phase: activePhase,
      storyPhase,
      scroll: scrollFraction,
      memoryIndex,
      pointer
    });
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

function shouldRunWebGL() {
  if (prefersQuiet() || slowConnection || compactViewport.matches) return false;
  try {
    const probe = document.createElement("canvas");
    return Boolean(probe.getContext("webgl2", { antialias: false }));
  } catch {
    return false;
  }
}

async function activateWorld() {
  if (!shouldRunWebGL()) {
    body.classList.add("fallback-world");
    return;
  }
  try {
    const module = await import("./world.js");
    world = module.createWorld(worldContainer);
    world.setMemory(memoryIndex);
    root.classList.add("webgl-ready");
  } catch (error) {
    // Failing to load WebGL must not break content, links or scrolling.
    body.classList.add("fallback-world");
    console.info("3D rendering unavailable; using the accessible still composition.");
  }
}
activateWorld();

window.addEventListener("pagehide", () => world?.destroy(), { once: true });
