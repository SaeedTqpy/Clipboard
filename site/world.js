/**
 * Memory Atlas — one continuous real-time Three.js scene.
 * All 3D geometry, ribbons and illustrated sample textures are original,
 * generated procedurally. They are a conceptual interpretation, not fake app UI.
 */
import * as THREE from "three";

const lerp = THREE.MathUtils.lerp;
const clamp = THREE.MathUtils.clamp;
const palettes = [0xd1ff88, 0xc3afff, 0x95cfef, 0xf5ba8e];

function roundedShape(width, height, radius = .25) {
  const s = new THREE.Shape();
  const x = -width / 2;
  const y = -height / 2;
  const r = Math.min(radius, width * .45, height * .45);
  s.moveTo(x + r, y);
  s.lineTo(x + width - r, y);
  s.quadraticCurveTo(x + width, y, x + width, y + r);
  s.lineTo(x + width, y + height - r);
  s.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
  s.lineTo(x + r, y + height);
  s.quadraticCurveTo(x, y + height, x, y + height - r);
  s.lineTo(x, y + r);
  s.quadraticCurveTo(x, y, x + r, y);
  return s;
}

function canvasRoundedRect(ctx, x, y, width, height, radius) {
  const r = Math.max(0, Math.min(radius, width * .5, height * .5));
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + width - r, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + r);
  ctx.lineTo(x + width, y + height - r);
  ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
  ctx.lineTo(x + r, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

function createTexture(type) {
  const canvas = document.createElement("canvas");
  canvas.width = 1100;
  canvas.height = 720;
  const g = canvas.getContext("2d", { alpha: true });
  if (!g) throw new Error("Canvas 2D unavailable");

  const base = g.createLinearGradient(0, 0, 1050, 740);
  const color = ["#303e35", "#332f45", "#233540", "#3e3032", "#27352e"][type];
  base.addColorStop(0, color);
  base.addColorStop(.53, "#171d22");
  base.addColorStop(1, "#0b1014");
  g.fillStyle = base;
  canvasRoundedRect(g, 18, 18, 1064, 684, 64);
  g.fill();

  // Iridescent edge and soft transparent reflection.
  g.strokeStyle = type === 0 ? "#cbff8680" : "#ffffff3c";
  g.lineWidth = 3;
  canvasRoundedRect(g, 20, 20, 1060, 680, 62);
  g.stroke();
  const sheen = g.createLinearGradient(0, 18, 1000, 350);
  sheen.addColorStop(0, "#ffffff28");
  sheen.addColorStop(.35, "#ffffff09");
  sheen.addColorStop(1, "#ffffff00");
  g.fillStyle = sheen;
  canvasRoundedRect(g, 30, 29, 1040, 220, 53);
  g.fill();

  const accent = ["#d1ff88", "#c3afff", "#94ccec", "#f6ba8c", "#d1ff88"][type];
  g.fillStyle = accent;
  g.beginPath();
  g.arc(90, 94, 11, 0, Math.PI * 2);
  g.fill();

  g.fillStyle = "#e6e6dc";
  g.font = "500 28px 'DM Mono', monospace";
  const tag = ["TEXT / 001", "CODE / 002", "LINK / 003", "IMAGE / 004", "FOLDER / 005"][type];
  g.fillText(tag, 126, 104);

  g.textAlign = "right";
  g.fillStyle = "#96aaa3";
  g.font = "500 23px 'DM Mono', monospace";
  g.fillText("CLIPBOARD  /  MEMORY", 1018, 104);
  g.textAlign = "left";

  if (type === 0) {
    g.fillStyle = "#f9faf6";
    g.font = "600 100px 'Space Grotesk', Arial";
    g.fillText("the next", 74, 340);
    g.fillText("big thing.", 74, 441);
    g.fillStyle = accent;
    g.font = "italic 86px 'Instrument Serif', Georgia";
    g.fillText("don't forget.", 78, 566);
  } else if (type === 1) {
    const lines = [
      ["const ", "memory", " = {"],
      ["  ", "capture", ": true,"],
      ["  ", "forget", ": false,"],
      ["  ", "focus", ": 'forever'"],
      ["};", "", ""]
    ];
    g.font = "500 52px 'DM Mono', monospace";
    lines.forEach((parts, i) => {
      const y = 267 + i * 75;
      const x = 74;
      g.fillStyle = "#b6a4d4";
      g.fillText(parts[0], x, y);
      let offset = g.measureText(parts[0]).width;
      g.fillStyle = i === 0 ? "#d1ff88" : "#b1cced";
      g.fillText(parts[1], x + offset, y);
      offset += g.measureText(parts[1]).width;
      g.fillStyle = "#ddd7e1";
      g.fillText(parts[2], x + offset, y);
    });
  } else if (type === 2) {
    g.fillStyle = "#eaf4ee";
    g.font = "600 79px 'Space Grotesk', Arial";
    g.fillText("somewhere", 75, 344);
    g.fillText("worth saving.", 75, 437);
    g.font = "500 35px 'DM Mono', monospace";
    g.fillStyle = accent;
    g.fillText("↗  example.org/the-idea", 78, 545);
  } else if (type === 3) {
    const gradient = g.createLinearGradient(40, 220, 1070, 640);
    gradient.addColorStop(0, "#b4c7bb");
    gradient.addColorStop(.4, "#aa80b0");
    gradient.addColorStop(1, "#535273");
    g.fillStyle = gradient;
    canvasRoundedRect(g, 69, 163, 965, 445, 29);
    g.fill();
    g.fillStyle = "#292e3ca8";
    g.beginPath();
    g.ellipse(760, 500, 410, 170, -.3, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = "#e6f5b2b0";
    g.beginPath();
    g.arc(280, 280, 75, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = "#203533bb";
    g.beginPath();
    g.ellipse(470, 570, 470, 180, -.18, 0, Math.PI * 2);
    g.fill();
  } else {
    g.fillStyle = "#f6f6ec";
    g.font = "600 94px 'Space Grotesk', Arial";
    g.fillText("all in", 74, 336);
    g.fillText("one place.", 74, 437);
    g.fillStyle = accent;
    g.font = "italic 80px 'Instrument Serif', Georgia";
    g.fillText("your ideas, intact.", 74, 560);
  }

  g.strokeStyle = "#ffffff32";
  g.lineWidth = 2;
  g.beginPath();
  g.moveTo(75, 641);
  g.lineTo(1028, 641);
  g.stroke();
  g.fillStyle = "#adb4b1";
  g.font = "500 22px 'DM Mono', monospace";
  g.fillText("RECENT MEMORY", 77, 675);
  g.fillStyle = accent;
  g.beginPath();
  g.arc(1012, 667, 8, 0, Math.PI * 2);
  g.fill();

  const map = new THREE.CanvasTexture(canvas);
  map.colorSpace = THREE.SRGBColorSpace;
  map.anisotropy = 4;
  return map;
}

function buildCard(type) {
  const g = new THREE.Group();
  const width = 4.15;
  const height = 2.72;
  const outline = new THREE.ExtrudeGeometry(roundedShape(width, height, .22), {
    steps: 1, depth: .13, bevelEnabled: true,
    bevelThickness: .045, bevelSize: .045, bevelSegments: 3,
    curveSegments: 12
  });
  outline.translate(0, 0, -.065);
  const edgeMaterial = new THREE.MeshPhysicalMaterial({
    color: type === 0 ? 0x839d73 : 0x484358,
    metalness: .68, roughness: .18, clearcoat: 1,
    transparent: true, opacity: .96
  });
  const back = new THREE.Mesh(outline, edgeMaterial);
  g.add(back);

  const face = new THREE.Mesh(
    new THREE.PlaneGeometry(width, height),
    new THREE.MeshBasicMaterial({
      map: createTexture(type), transparent: true,
      side: THREE.FrontSide, depthWrite: true
    })
  );
  face.position.z = .125;
  g.add(face);

  const outlineShape = roundedShape(width + .08, height + .08, .25);
  const edge = new THREE.LineLoop(
    new THREE.BufferGeometry().setFromPoints(
      outlineShape.getPoints(82).map((p) => new THREE.Vector3(p.x, p.y, .132))
    ),
    new THREE.LineBasicMaterial({
      color: type === 0 ? 0xd1ff88 : 0xc2aefc,
      transparent: true, opacity: .29
    })
  );
  g.add(edge);
  g.userData.type = type;
  g.userData.face = face;
  return g;
}

function createRibbons() {
  const result = new THREE.Group();
  const settings = [
    { phase: 0, color: 0xd1ff88, radius: 3.6, opacity: .35 },
    { phase: 2, color: 0xc4afff, radius: 4.35, opacity: .25 },
    { phase: 5, color: 0x80bdca, radius: 3.0, opacity: .21 }
  ];

  settings.forEach((s, index) => {
    const positions = [];
    const steps = 170;
    for (let i = 0; i <= steps; i++) {
      const t = i / steps * Math.PI * 2;
      const wave = .32 * Math.sin(t * 3 + s.phase);
      positions.push(new THREE.Vector3(
        Math.cos(t) * (s.radius + wave),
        Math.sin(t) * (s.radius * .48 + wave * .7),
        Math.sin(t * 2 + s.phase) * .92 - 1.4
      ));
    }
    const curve = new THREE.CatmullRomCurve3(positions, true);
    const tube = new THREE.Mesh(
      new THREE.TubeGeometry(curve, 215, .012 + index * .004, 6, true),
      new THREE.MeshBasicMaterial({
        color: s.color, transparent: true, opacity: s.opacity,
        blending: THREE.AdditiveBlending, depthWrite: false
      })
    );
    tube.rotation.set(.9 + index * .3, .2, .3 + index * .75);
    result.add(tube);
  });
  return result;
}

function createDust(count = 400) {
  let seed = 6923;
  const rnd = () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 4294967296;
  };
  const data = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    data[i * 3] = (rnd() - .5) * 24;
    data[i * 3 + 1] = (rnd() - .5) * 14;
    data[i * 3 + 2] = (rnd() - .5) * 14 - 2;
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.BufferAttribute(data, 3));
  return new THREE.Points(geometry, new THREE.PointsMaterial({
    size: .029, color: 0xc2d5c6, opacity: .42,
    transparent: true, blending: THREE.AdditiveBlending, depthWrite: false,
    sizeAttenuation: true
  }));
}

const ORB_VERTEX = [
  "varying vec3 vNormal;",
  "varying vec3 vPosition;",
  "void main(){",
  "vNormal = normalize(normalMatrix * normal);",
  "vPosition = position;",
  "gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0);",
  "}"
].join("\n");

const ORB_FRAGMENT = [
  "uniform float uTime;",
  "uniform float uScroll;",
  "uniform vec3 uAccent;",
  "varying vec3 vNormal;",
  "varying vec3 vPosition;",
  "void main(){",
  "float edge=pow(1.0-abs(dot(normalize(vNormal),vec3(0.,0.,1.))),2.7);",
  "float ripple=sin(vPosition.y*11.0+uTime*.9+sin(vPosition.x*6.0))*0.5+0.5;",
  "vec3 violet=vec3(.56,.47,.89);",
  "vec3 c=mix(violet,uAccent,ripple*.62+uScroll*.17);",
  "gl_FragColor=vec4(c*(.2+edge*1.4),.15+edge*.54);",
  "}"
].join("\n");

const layoutModes = [
  // x, y, scale, x-rotation, y-rotation, z-rotation, spread, glow, depth
  [2.38, .00, 1.16, -.10, -.25, -.08, .10, 1.0, 0],
  [2.95, .05, .80, -.12,  .30,  .15, .68, .75, -.3],
  [ .00, .15, 1.22,  .08, -.18, -.08, .94, 1.0, 0],
  [-2.25,.08, 1.06, -.12, -.08, -.03, .83, 1.0, 0],
  [2.36, .08, 1.14, -.16, -.22, -.09, .73, 1.1, 0],
  [0,  .12, .66, -.23,  .40, .15, .26, .35, -1.3],
  [2.73, .15, .70, -.20,  .12, .06, .69, .42, -.8],
  [2.46, .05, 1.08, -.07, -.38, -.10, .34, .91, -.4]
];
function modeAt(phase) {
  const a = clamp(Math.floor(phase), 0, layoutModes.length - 1);
  const b = Math.min(a + 1, layoutModes.length - 1);
  const blend = THREE.MathUtils.smoothstep(phase - a, 0, 1);
  return layoutModes[a].map((value, i) => lerp(value, layoutModes[b][i], blend));
}

export function createWorld(container) {
  const renderer = new THREE.WebGLRenderer({
    alpha: true, antialias: true, powerPreference: "high-performance"
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.7));
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.24;
  renderer.setClearColor(0x000000, 0);
  renderer.domElement.setAttribute("aria-hidden", "true");
  renderer.domElement.className = "cinema__webgl";
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(38, window.innerWidth / window.innerHeight, .1, 70);
  camera.position.set(0, 0, 11.9);

  const ambient = new THREE.AmbientLight(0xc2d2e4, 1.45);
  scene.add(ambient);
  const key = new THREE.PointLight(0xd7ff9e, 33, 28);
  key.position.set(4.4, 4, 6);
  scene.add(key);
  const rim = new THREE.PointLight(0x9982e6, 28, 23);
  rim.position.set(-4.5, -3, 2);
  scene.add(rim);

  const dust = createDust(470);
  scene.add(dust);

  const worldGroup = new THREE.Group();
  const deck = new THREE.Group();
  worldGroup.add(deck);
  scene.add(worldGroup);

  const cards = [0,1,2,3,4].map((i) => buildCard(i));
  // Render ordering is depth-driven; each piece can move independently.
  cards.forEach((card) => deck.add(card));

  const ribbons = createRibbons();
  worldGroup.add(ribbons);

  const orbMaterial = new THREE.ShaderMaterial({
    transparent: true,
    side: THREE.DoubleSide,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    uniforms: {
      uTime: { value: 0 },
      uScroll: { value: 0 },
      uAccent: { value: new THREE.Color(palettes[0]) }
    },
    vertexShader: ORB_VERTEX,
    fragmentShader: ORB_FRAGMENT
  });
  const orb = new THREE.Mesh(new THREE.IcosahedronGeometry(1.0, 5), orbMaterial);
  orb.position.set(.1, .1, -2.15);
  worldGroup.add(orb);

  const origin = [
    [-.58,-.26,1.14,-.14],
    [ .39, .32, .46, .13],
    [ .77, .63,-.25, .20],
    [-.75, .68,-1.0,-.22],
    [ .11,-.66,-1.65, .07]
  ];
  const exploded = [
    [-.84,-.32, 2.0,-.16],
    [ 1.34, .96, .90, .21],
    [ 2.42,-.25,-.05,.12],
    [-2.21,1.0,-1.03,-.23],
    [ -.20,-1.58,-1.8,.08]
  ];

  let selected = 0;
  let lastFrame = 0;
  let disposed = false;
  const px = new THREE.Vector3();
  const accent = new THREE.Color(palettes[0]);
  const intendedAccent = new THREE.Color(palettes[0]);

  function resize() {
    if (disposed) return;
    const width = window.innerWidth, height = window.innerHeight;
    camera.aspect = width / Math.max(1, height);
    // Preserve useful space on 4:3 desktops and narrower windows.
    camera.fov = width < 1000 ? 45 : 38;
    camera.updateProjectionMatrix();
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, width < 1000 ? 1.3 : 1.7));
    renderer.setSize(width, height, false);
  }
  window.addEventListener("resize", resize, { passive: true });

  function render({ time, dt, phase, storyPhase, scroll, pointer }) {
    if (disposed) return;
    const dtFixed = Math.min(dt || .016, .06);
    const damping = 1 - Math.exp(-dtFixed * 3.5);
    const mode = modeAt(phase);
    const [x,y,size,rotX,rotY,rotZ,spread,intensity,depth] = mode;
    const inStory = Math.max(0, 1 - Math.abs(phase - 3) * 1.5);
    const inLab = Math.max(0, 1 - Math.abs(phase - 4) * 1.5);
    const drift = Math.sin(time * .37) * .10;
    const parallaxX = pointer.x * .16;
    const parallaxY = -pointer.y * .11;

    worldGroup.position.x = lerp(worldGroup.position.x, x + parallaxX, damping);
    worldGroup.position.y = lerp(worldGroup.position.y, y + drift + parallaxY, damping);
    worldGroup.position.z = lerp(worldGroup.position.z, depth, damping);
    worldGroup.scale.setScalar(lerp(worldGroup.scale.x, size, damping));
    worldGroup.rotation.x = lerp(worldGroup.rotation.x, rotX + pointer.y * .055, damping);
    worldGroup.rotation.y = lerp(worldGroup.rotation.y, rotY + pointer.x * .10 + time * .014, damping);
    worldGroup.rotation.z = lerp(worldGroup.rotation.z, rotZ, damping);

    const activeStory = Math.min(3, Math.max(0, Math.round(storyPhase)));
    const spreadAmount = clamp(spread + inStory * .12, 0, 1.4);
    cards.forEach((card, i) => {
      const from = origin[i];
      const to = exploded[i];
      const focus = inLab * (i === selected ? 1.0 : -.13);
      const storyLift = inStory * (i === activeStory ? .35 : 0);
      px.set(
        lerp(from[0], to[0], spreadAmount) + (i === selected ? inLab * -.23 : 0),
        lerp(from[1], to[1], spreadAmount) + storyLift,
        lerp(from[2], to[2], spreadAmount) + focus * 1.08
      );
      card.position.lerp(px, damping * 1.3);
      card.rotation.z = lerp(card.rotation.z,
        lerp(from[3], to[3], spreadAmount) + Math.sin(time * .37 + i * 1.3) * .025,
        damping);
      card.rotation.x = lerp(card.rotation.x, -.025 + Math.sin(time *.55+i) *.022, damping);
      card.rotation.y = lerp(card.rotation.y, Math.cos(time * .32 + i * 1.2) * .045, damping);
      const scale = i === selected ? 1 + inLab * .11 : 1;
      card.scale.setScalar(lerp(card.scale.x, scale, damping));
      card.userData.face.material.opacity = lerp(
        card.userData.face.material.opacity,
        inLab > .25 && i !== selected ? .82 : 1, damping
      );
    });

    ribbons.rotation.y = time * .035 + scroll * .7;
    ribbons.rotation.z = Math.sin(time * .19) * .10 + scroll * .17;
    ribbons.scale.setScalar(lerp(ribbons.scale.x, .94 + intensity * .13, damping));
    const ringsOpacity = .48 + intensity * .52;
    ribbons.children.forEach((mesh, i) => {
      mesh.material.opacity = (i === 0 ? .3 : .22) * ringsOpacity;
    });
    dust.rotation.y = time * .005 + scroll * .12;
    dust.rotation.z = time * .003;

    intendedAccent.setHex(palettes[selected]);
    accent.lerp(intendedAccent, damping * .8);
    orbMaterial.uniforms.uAccent.value.copy(accent);
    orbMaterial.uniforms.uTime.value = time;
    orbMaterial.uniforms.uScroll.value = scroll;
    orb.rotation.y = time * .19;
    orb.rotation.x = time * .08;
    orb.scale.setScalar(lerp(orb.scale.x, phase > 4.65 && phase < 5.5 ? 2.1 : 1, damping));
    key.color.copy(accent);

    camera.position.x = lerp(camera.position.x, -pointer.x * .12, damping);
    camera.position.y = lerp(camera.position.y, pointer.y * .08, damping);
    camera.lookAt(0, 0, 0);

    // Cap continuous rendering to ~50fps to preserve battery/thermal budget.
    if (time - lastFrame > 1/50) {
      renderer.render(scene, camera);
      lastFrame = time;
    }
  }

  function destroy() {
    if (disposed) return;
    disposed = true;
    window.removeEventListener("resize", resize);
    scene.traverse((node) => {
      node.geometry?.dispose?.();
      if (node.material) {
        const materials = Array.isArray(node.material) ? node.material : [node.material];
        materials.forEach((mat) => { mat.map?.dispose?.(); mat.dispose?.(); });
      }
    });
    renderer.dispose();
    renderer.domElement.remove();
  }

  return {
    setMemory(index) { selected = clamp(index, 0, palettes.length - 1); },
    render,
    destroy
  };
}
