import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const q = new URLSearchParams(location.search);
const W = +(q.get('w') || 900), H = +(q.get('h') || 1100);
const scenes = (q.get('scenes') || '').split(',');
const views = (q.get('views') || '30').split(',').map(Number); // yaw degrees (0 = looking at the front)
const bg = q.get('bg') || '#2a2c33';

const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
renderer.setSize(W * views.length, H * scenes.length);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = +(q.get('exp') || 1.0);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.setScissorTest(true);
document.body.appendChild(renderer.domElement);

const pmrem = new THREE.PMREMGenerator(renderer);
const envTex = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;

const data = await (await fetch('scene.json')).json();
const loadImg = (src) => new Promise((res) => { const i = new Image(); i.onload = () => res(i); i.onerror = () => res(null); i.src = src; });

const TORSO = { U: [231, 8, 128, 64], F: [231, 74, 128, 128], R: [165, 74, 64, 128], L: [361, 74, 64, 128], B: [427, 74, 128, 128], D: [231, 204, 128, 64] };
const RIGHT = { U: [217, 289, 64, 64], D: [217, 485, 64, 64], L: [19, 355, 64, 128], B: [85, 355, 64, 128], R: [151, 355, 64, 128], F: [217, 355, 64, 128] };
const LEFT = { U: [308, 289, 64, 64], D: [308, 485, 64, 64], F: [308, 355, 64, 128], L: [374, 355, 64, 128], B: [440, 355, 64, 128], R: [506, 355, 64, 128] };
// which slice (v0..v1 down the region) of the template each R15 part shows
const SLICE = {
  UpperTorso: ['shirt', 'T', 0, 0.8], LowerTorso: ['pants', 'T', 0.8, 1],
  UpperArm: ['shirt', 'A', 0, 0.46], LowerArm: ['shirt', 'A', 0.46, 0.88], Hand: ['shirt', 'A', 0.88, 1],
  UpperLeg: ['pants', 'A', 0, 0.48], LowerLeg: ['pants', 'A', 0.48, 0.9], Foot: ['pants', 'A', 0.9, 1],
};

function matFor(p) {
  const c = new THREE.Color(`rgb(${p.color.join(',')})`);
  const m = p.mat;
  const refl = p.refl || 0;
  if (m === 'Neon') {
    return new THREE.MeshBasicMaterial({ color: c.clone().multiplyScalar(1.6), transparent: p.tr > 0, opacity: 1 - p.tr, toneMapped: false });
  }
  let rough = 0.5, metal = 0.0;
  if (m === 'Metal' || m === 'DiamondPlate' || m === 'CorrodedMetal') { rough = 0.32; metal = 0.75; }
  else if (m === 'SmoothPlastic') rough = 0.42;
  else if (m === 'Plastic') rough = 0.55;
  else if (m === 'Leather') rough = 0.62;
  else if (m === 'Fabric' || m === 'Rubber') rough = 0.92;
  else if (m === 'Glass') rough = 0.05;
  else if (m === 'Foil') { rough = 0.2; metal = 0.9; }
  rough = Math.max(0.05, rough - refl * 0.6);
  metal = Math.min(1, metal + refl * 0.8);
  return new THREE.MeshStandardMaterial({ color: c, roughness: rough, metalness: metal, envMap: envTex, envMapIntensity: 0.8 + refl * 2,
    transparent: p.tr > 0.01, opacity: 1 - p.tr });
}

function wedgeGeo(sx, sy, sz) {
  // Roblox wedge: flat bottom, tall back (+Z), slope rising from the front-bottom edge
  const x = sx / 2, y = sy / 2, z = sz / 2;
  const v = [
    [-x, -y, -z], [x, -y, -z], [x, -y, z], [-x, -y, z], // bottom
    [-x, y, z], [x, y, z], // top back edge
  ];
  const tris = [[0, 2, 1], [0, 3, 2], [3, 5, 2], [3, 4, 5], [0, 1, 5], [0, 5, 4], [0, 4, 3], [1, 2, 5]];
  const pos = [];
  for (const t of tris) for (const i of t) pos.push(...v[i]);
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.computeVertexNormals();
  return g;
}

function cfMatrix(cf) {
  const [x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22] = cf;
  const m = new THREE.Matrix4();
  m.set(r00, r01, r02, x, r10, r11, r12, y, r20, r21, r22, z, 0, 0, 0, 1);
  return m;
}

// -- SurfaceGui painting ---------------------------------------------------
function roundRect(ctx, x, y, w, h, r) {
  r = Math.max(0, Math.min(r, w / 2, h / 2));
  ctx.beginPath();
  ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}
function paintNodes(ctx, nodes, pw, ph) {
  const sorted = nodes.map((n, i) => [n, i]).sort((a, b) => (a[0].z - b[0].z) || (a[1] - b[1]));
  for (const [n] of sorted) {
    if (!n.visible) continue;
    const w = n.size[0] * pw + n.size[1], h = n.size[2] * ph + n.size[3];
    const x = n.pos[0] * pw + n.pos[1] - n.anchor[0] * w, y = n.pos[2] * ph + n.pos[3] - n.anchor[1] * h;
    ctx.save();
    ctx.translate(x + w / 2, y + h / 2);
    ctx.rotate(n.rot * Math.PI / 180);
    ctx.translate(-w / 2, -h / 2);
    const r = n.corner ? n.corner[0] * Math.min(w, h) + n.corner[1] : 0;
    if (n.bgt < 1) {
      ctx.globalAlpha = 1 - n.bgt;
      ctx.fillStyle = `rgb(${n.bg.join(',')})`;
      roundRect(ctx, 0, 0, w, h, r); ctx.fill();
      ctx.globalAlpha = 1;
    }
    if (n.stroke && n.stroke.border) {
      const t = n.stroke.t;
      ctx.globalAlpha = 1 - n.stroke.tr;
      ctx.strokeStyle = `rgb(${n.stroke.c.join(',')})`;
      ctx.lineWidth = t;
      roundRect(ctx, -t / 2, -t / 2, w + t, h + t, r + t / 2); ctx.stroke();
      ctx.globalAlpha = 1;
    }
    if (n.text) {
      ctx.fillStyle = `rgb(${n.tc.join(',')})`;
      ctx.globalAlpha = 1 - (n.tt || 0);
      let fs = Math.min(h * 0.8, w / Math.max(1, n.text.length * 0.55));
      ctx.font = `bold ${fs}px Oswald, sans-serif`;
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(n.text, w / 2, h / 2);
      ctx.globalAlpha = 1;
    }
    paintNodes(ctx, n.children, w, h);
    ctx.restore();
  }
}
const FACES = { // normal, canvas-right, canvas-up (part space)
  Front: [[0, 0, -1], [-1, 0, 0], [0, 1, 0]], Back: [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
  Right: [[1, 0, 0], [0, 0, -1], [0, 1, 0]], Left: [[-1, 0, 0], [0, 0, 1], [0, 1, 0]],
  Top: [[0, 1, 0], [-1, 0, 0], [0, 0, -1]], Bottom: [[0, -1, 0], [-1, 0, 0], [0, 0, 1]],
};
function faceDims(size, face) {
  const [sx, sy, sz] = size;
  if (face === 'Front' || face === 'Back') return [sx, sy, sz / 2];
  if (face === 'Right' || face === 'Left') return [sz, sy, sx / 2];
  return [sx, sz, sy / 2];
}
function guiPlane(p, g) {
  const face = g.face.replace('Enum.NormalId.', '');
  const [fw, fh, off] = faceDims(p.size, face);
  let cw, ch;
  if (g.mode.includes('PixelsPerStud')) { cw = fw * g.pps; ch = fh * g.pps; } else { cw = g.canvas[0]; ch = g.canvas[1]; }
  const scale = Math.min(1, 2048 / Math.max(cw, ch));
  const cv = document.createElement('canvas');
  cv.width = Math.max(2, Math.round(cw * scale)); cv.height = Math.max(2, Math.round(ch * scale));
  const ctx = cv.getContext('2d');
  ctx.scale(scale, scale);
  paintNodes(ctx, g.tree, cw, ch);
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  const mat = new THREE.MeshStandardMaterial({ map: tex, transparent: true, roughness: 0.6, polygonOffset: true, polygonOffsetFactor: -2 });
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(fw, fh), mat);
  const [n, r, u] = FACES[face];
  const basis = new THREE.Matrix4().makeBasis(new THREE.Vector3(...r), new THREE.Vector3(...u), new THREE.Vector3(...n));
  basis.setPosition(n[0] * (off + 0.003), n[1] * (off + 0.003), n[2] * (off + 0.003));
  mesh.matrixAutoUpdate = false;
  mesh.matrix.copy(basis);
  return mesh;
}

// -- clothing templates ------------------------------------------------------
const imgCache = {};
async function templ(skin, kind) {
  const key = skin + kind;
  if (!(key in imgCache)) imgCache[key] = await loadImg(`../../assets/textures/${skin}_${kind === 'shirt' ? 'Shirt' : 'Pants'}.png`);
  return imgCache[key];
}
function faceTex(p, base, layers) {
  // layers: [{img, rect, v0, v1}] painted bottom to top over the base colour
  const cv = document.createElement('canvas'); cv.width = 128; cv.height = 128;
  const ctx = cv.getContext('2d');
  ctx.fillStyle = `rgb(${base.join(',')})`; ctx.fillRect(0, 0, 128, 128);
  for (const l of layers) {
    if (!l.img) continue;
    const [x, y, w, h] = l.rect;
    ctx.drawImage(l.img, x, y + h * l.v0, w, h * (l.v1 - l.v0), 0, 0, 128, 128);
  }
  const t = new THREE.CanvasTexture(cv); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  return t;
}

async function build(sceneName) {
  const group = new THREE.Group();
  const sc = data[sceneName];
  const skin = sc.skin;
  const tex = { shirt: sc.shirt, pants: sc.pants };
  for (const p of sc.parts) {
    let geo;
    const [sx, sy, sz] = p.size;
    const shape = p.shape.replace('Enum.PartType.', '');
    const mesh = p.mesh && p.mesh.type.replace('Enum.MeshType.', '');
    if (mesh === 'Sphere') { geo = new THREE.SphereGeometry(0.5, 32, 20); geo.scale(sx, sy, sz); }
    else if (p.class === 'WedgePart') geo = wedgeGeo(sx, sy, sz);
    else if (shape === 'Cylinder') { geo = new THREE.CylinderGeometry(Math.min(sy, sz) / 2, Math.min(sy, sz) / 2, sx, 32); geo.rotateZ(Math.PI / 2); }
    else if (shape === 'Ball') geo = new THREE.SphereGeometry(Math.min(sx, sy, sz) / 2, 32, 20);
    else geo = new THREE.BoxGeometry(sx, sy, sz);
    let material = matFor(p);
    // body parts wear the clothing templates
    const slot = p.name.replace(/^(Right|Left)/, '');
    const sl = SLICE[slot];
    if (sl && p.class === 'MeshPart' && tex[sl[0]]) {
      const img = await templ(skin, sl[0]);
      const side = p.name.startsWith('Right') ? RIGHT : LEFT;
      const regions = sl[1] === 'T' ? TORSO : side;
      const order = ['R', 'L', 'U', 'D', 'B', 'F']; // three.js box face order: +X -X +Y -Y +Z -Z
      const layersFor = (f) => {
        const L = [{ img, rect: regions[f], v0: (f === 'U' || f === 'D') ? 0 : sl[2], v1: (f === 'U' || f === 'D') ? 1 : sl[3] }];
        if (slot === 'LowerTorso' && tex.shirt) L.push({ img: imgCache[skin + 'shirt'] || null, rect: TORSO[f], v0: f === 'U' || f === 'D' ? 0 : 0.8, v1: 1 });
        return L;
      };
      if (slot === 'LowerTorso' && tex.shirt) await templ(skin, 'shirt');
      material = order.map((f) => {
        if ((f === 'U' && !['UpperTorso', 'UpperArm', 'UpperLeg'].includes(slot)) || (f === 'D' && !['LowerTorso', 'Hand', 'Foot'].includes(slot))) return matFor(p);
        const m = matFor(p); m.map = faceTex(p, p.color, layersFor(f)); m.color = new THREE.Color(1, 1, 1); return m;
      });
    }
    const obj = new THREE.Mesh(geo, material);
    obj.castShadow = p.tr < 0.5; obj.receiveShadow = true;
    obj.matrixAutoUpdate = false;
    obj.matrix.copy(cfMatrix(p.cf));
    if (p.tr >= 0.999) obj.material = new THREE.MeshBasicMaterial({ visible: false });
    for (const g of p.guis) obj.add(guiPlane(p, g));
    for (const l of p.lights) {
      const pl = new THREE.PointLight(new THREE.Color(`rgb(${l.c.join(',')})`), l.b * 3, l.range * 1.2, 2);
      obj.add(pl);
    }
    group.add(obj);
  }
  return group;
}

const built = [];
for (const s of scenes) built.push(await build(s));

// compose=1: every scene in one shot (a thumbnail). place = "x,y,z,yaw,scale;..."
// per scene, cam / look = "x,y,z", fov. Neon glows through a bloom pass.
if (q.get('compose')) {
  const { EffectComposer } = await import('three/addons/postprocessing/EffectComposer.js');
  const { RenderPass } = await import('three/addons/postprocessing/RenderPass.js');
  const { UnrealBloomPass } = await import('three/addons/postprocessing/UnrealBloomPass.js');
  const { OutputPass } = await import('three/addons/postprocessing/OutputPass.js');
  renderer.setScissorTest(false);
  renderer.setSize(W, H);
  const scene = new THREE.Scene();
  const bgc = document.createElement('canvas'); bgc.width = 16; bgc.height = 256;
  const bctx = bgc.getContext('2d');
  const grad = bctx.createLinearGradient(0, 0, 0, 256);
  grad.addColorStop(0, q.get('bgTop') || '#07080c'); grad.addColorStop(0.62, q.get('bgMid') || '#1b1d26'); grad.addColorStop(1, '#0b0c10');
  bctx.fillStyle = grad; bctx.fillRect(0, 0, 16, 256);
  const bgTex = new THREE.CanvasTexture(bgc); bgTex.colorSpace = THREE.SRGBColorSpace;
  scene.background = bgTex;
  scene.environment = envTex;
  scene.fog = new THREE.Fog(0x0c0d12, 40, 110);
  const place = (q.get('place') || '').split(';').map((p) => p.split(',').map(Number));
  built.forEach((g, i) => {
    const [x = 0, y = 0, z = 0, yaw = 0, sc = 1] = place[i] || [];
    const box = new THREE.Box3().setFromObject(g);
    const holder = new THREE.Group();
    g.position.y -= box.min.y; // feet on the floor
    holder.add(g);
    holder.scale.setScalar(sc);
    holder.rotation.y = yaw * Math.PI / 180;
    holder.position.set(x, y, z);
    holder.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    scene.add(holder);
  });
  // backdrop=1: a facility wall behind them (steel panels, a hazard band,
  // a row of caged lamps)
  if (q.get('backdrop')) {
    const wc = document.createElement('canvas'); wc.width = 4096; wc.height = 1024;
    const w = wc.getContext('2d');
    w.fillStyle = '#15161b'; w.fillRect(0, 0, 4096, 1024);
    for (let x = 0; x < 4096; x += 160) {
      w.fillStyle = x % 320 ? '#1a1b21' : '#17181e'; w.fillRect(x, 0, 156, 1024);
      w.fillStyle = '#0b0c0f'; w.fillRect(x + 156, 0, 4, 1024);
      for (const y of [120, 520, 900]) { w.fillStyle = '#2a2b32'; w.beginPath(); w.arc(x + 20, y, 6, 0, 7); w.arc(x + 136, y, 6, 0, 7); w.fill(); }
    }
    w.save(); w.beginPath(); w.rect(0, 800, 4096, 90); w.clip();
    for (let x = -200; x < 4300; x += 80) { w.fillStyle = (x / 80) % 2 ? '#d8a818' : '#111'; w.beginPath(); w.moveTo(x, 890); w.lineTo(x + 40, 890); w.lineTo(x + 130, 800); w.lineTo(x + 90, 800); w.fill(); }
    w.restore();
    for (let x = 200; x < 4096; x += 480) {
      const g = w.createRadialGradient(x, 330, 4, x, 330, 150);
      g.addColorStop(0, 'rgba(255,214,140,0.95)'); g.addColorStop(0.12, 'rgba(255,190,110,0.5)'); g.addColorStop(1, 'rgba(255,170,90,0)');
      w.fillStyle = g; w.fillRect(x - 160, 170, 320, 320);
      w.fillStyle = '#fff2d8'; w.fillRect(x - 26, 318, 52, 24);
    }
    const wt = new THREE.CanvasTexture(wc); wt.colorSpace = THREE.SRGBColorSpace; wt.anisotropy = 8;
    const wall = new THREE.Mesh(new THREE.PlaneGeometry(120, 30), new THREE.MeshBasicMaterial({ map: wt, fog: true }));
    wall.position.set(0, 15, +(q.get('wallZ') || 22)); wall.rotation.y = Math.PI; scene.add(wall);
  }
  // a dark steel floor with a sheen
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), new THREE.MeshStandardMaterial({ color: 0x0e0f13, roughness: 0.85, metalness: 0.2, envMap: envTex, envMapIntensity: 0.2 }));
  floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; scene.add(floor);
  // floor grid lines
  scene.add(new THREE.HemisphereLight(0xb8c4ff, 0x201a18, 0.55));
  const key = new THREE.DirectionalLight(0xfff0dc, +(q.get('key') || 2.6)); key.position.set(-14, 22, -18); key.castShadow = true;
  key.shadow.mapSize.set(4096, 4096); Object.assign(key.shadow.camera, { left: -30, right: 30, top: 30, bottom: -10, far: 120 }); key.shadow.bias = -0.0004;
  scene.add(key);
  const rimY = new THREE.DirectionalLight(0xffc830, 2.4); rimY.position.set(8, 16, 30); scene.add(rimY);
  const rimR = new THREE.DirectionalLight(0xff3020, 1.6); rimR.position.set(-20, 6, 18); scene.add(rimR);
  for (const extra of (q.get('lights') || '').split(';').filter(Boolean)) {
    const [x, y, z, hex, pow, range] = extra.split(',');
    const l = new THREE.PointLight(new THREE.Color('#' + hex), +pow, +range, 2); l.position.set(+x, +y, +z); scene.add(l);
  }
  const cam = new THREE.PerspectiveCamera(+(q.get('fov') || 35), W / H, 0.1, 300);
  cam.position.set(...(q.get('cam') || '0,6,-30').split(',').map(Number));
  cam.lookAt(new THREE.Vector3(...(q.get('look') || '0,5,0').split(',').map(Number)));
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, cam));
  composer.addPass(new UnrealBloomPass(new THREE.Vector2(W, H), +(q.get('bloom') || 0.4), 0.5, +(q.get('bloomAt') || 0.97)));
  composer.addPass(new OutputPass());
  composer.render();
  document.title = 'done';
  throw new Error('composed'); // stop here
}

for (let si = 0; si < scenes.length; si++) {
  for (let vi = 0; vi < views.length; vi++) {
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(bg);
    scene.environment = envTex;
    const g = built[si].clone();
    scene.add(g);
    const box = new THREE.Box3().setFromObject(g);
    const c = box.getCenter(new THREE.Vector3()), sz = box.getSize(new THREE.Vector3());
    const floor = new THREE.Mesh(new THREE.CircleGeometry(6, 48), new THREE.MeshStandardMaterial({ color: 0x3a3c44, roughness: 0.9 }));
    floor.rotation.x = -Math.PI / 2; floor.position.y = box.min.y; floor.receiveShadow = true; scene.add(floor);
    scene.add(new THREE.HemisphereLight(0xdfe8ff, 0x3a3230, 0.9));
    const key = new THREE.DirectionalLight(0xfff2e0, 2.4); key.position.set(-5, 9, -7); key.castShadow = true;
    key.shadow.mapSize.set(2048, 2048); key.shadow.camera.left = -5; key.shadow.camera.right = 5; key.shadow.camera.top = 8; key.shadow.camera.bottom = -2;
    key.shadow.bias = -0.0005;
    scene.add(key);
    const rim = new THREE.DirectionalLight(0x9fc4ff, 1.6); rim.position.set(6, 5, 7); scene.add(rim);
    const yaw = views[vi] * Math.PI / 180;
    const pitch = +(q.get('pitch') || 8) * Math.PI / 180;
    const dist = Math.max(sz.y, sz.x) * +(q.get('zoom') || 1.9);
    const cam = new THREE.PerspectiveCamera(32, W / H, 0.1, 100);
    const look = new THREE.Vector3(c.x, c.y + +(q.get('dy') || 0), c.z);
    cam.position.set(look.x - Math.sin(yaw) * dist * Math.cos(pitch), look.y + Math.sin(pitch) * dist, look.z - Math.cos(yaw) * dist * Math.cos(pitch));
    cam.lookAt(look);
    const x = vi * W, y = (scenes.length - 1 - si) * H;
    renderer.setViewport(x, y, W, H); renderer.setScissor(x, y, W, H);
    renderer.render(scene, cam);
  }
}
document.title = 'done';
