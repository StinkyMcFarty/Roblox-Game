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
