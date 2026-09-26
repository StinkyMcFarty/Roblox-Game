// Thumbnail renderer: the Sentinel Hangar (hangar.json) + posed characters
// (chars.json), cinematic lights, haze beams, sparks, bloom.
// ?depth=1 renders a depth pass for the post-processing (DOF, fog grade).
import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
const q = new URLSearchParams(location.search);
const W = +(q.get('w') || 1920), H = +(q.get('h') || 1080);
const DEPTH = !!q.get('depth');
const V3 = (s) => new THREE.Vector3(...s.split(',').map(Number));
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1); renderer.setSize(W, H);
renderer.toneMapping = DEPTH ? THREE.NoToneMapping : THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = +(q.get('exp') || 1.0);
renderer.outputColorSpace = DEPTH ? THREE.LinearSRGBColorSpace : THREE.SRGBColorSpace;
renderer.shadowMap.enabled = !DEPTH; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);
const pmrem = new THREE.PMREMGenerator(renderer);
const envTex = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
const chars = await (await fetch(q.get('chars') || 'chars.json')).json();
const room = await (await fetch('hangar.json')).json();


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
    let w = n.size[0] * pw + n.size[1], h = n.size[2] * ph + n.size[3];
    if (n.aspect) { if (w / h > n.aspect) w = h * n.aspect; else h = w / n.aspect; }
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
    if (n.clip) { ctx.beginPath(); ctx.rect(0, 0, w, h); ctx.clip(); }
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
  const sc = chars[sceneName];
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
    obj.userData.part = { name: p.name, cls: p.class };
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
// -- grime: world-space noise breaks up flat albedo and roughness ------------
const GRIME = `
float hsh(vec3 p){ p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x){ vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(hsh(i), hsh(i + vec3(1,0,0)), f.x), mix(hsh(i + vec3(0,1,0)), hsh(i + vec3(1,1,0)), f.x), f.y),
             mix(mix(hsh(i + vec3(0,0,1)), hsh(i + vec3(1,0,1)), f.x), mix(hsh(i + vec3(0,1,1)), hsh(i + vec3(1,1,1)), f.x), f.y), f.z); }
float fbm(vec3 p){ return vn(p) * 0.5 + vn(p * 2.03) * 0.25 + vn(p * 4.1) * 0.125 + vn(p * 8.3) * 0.0625; }`;
function grime(m, amount) {
  m.onBeforeCompile = (sh) => {
    sh.vertexShader = sh.vertexShader.replace('#include <common>', '#include <common>\nvarying vec3 vWP;')
      .replace('#include <worldpos_vertex>', '#include <worldpos_vertex>\nvWP = (modelMatrix * vec4(transformed, 1.0)).xyz;');
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', '#include <common>\nvarying vec3 vWP;' + GRIME)
      .replace('#include <color_fragment>', `#include <color_fragment>
        float g = fbm(vWP * 0.9); float s = fbm(vWP * 0.18 + 7.0);
        diffuseColor.rgb *= mix(1.0, 0.72 + 0.5 * g, ${amount.toFixed(2)}) * mix(1.0, 0.8 + 0.35 * s, ${amount.toFixed(2)});`)
      .replace('#include <roughnessmap_fragment>', `#include <roughnessmap_fragment>
        roughnessFactor = clamp(roughnessFactor + (fbm(vWP * 1.7) - 0.5) * ${(amount * 0.6).toFixed(2)}, 0.04, 1.0);`);
  };
  return m;
}
function roomMat(p) {
  const c = new THREE.Color(`rgb(${p.color.join(',')})`);
  const m = p.mat.replace('Enum.Material.', '');
  const refl = p.refl || 0;
  if (m === 'Neon') return new THREE.MeshBasicMaterial({ color: c.clone().multiplyScalar(+(q.get('neon') || 1.5) * (p.cf[1] > 20 ? +(q.get('highNeon') || 1) : 1)), transparent: p.tr > 0, opacity: 1 - p.tr, toneMapped: false, fog: false });
  let rough = 0.62, metal = 0.0;
  if (m === 'Metal' || m === 'DiamondPlate' || m === 'CorrodedMetal') { rough = 0.38; metal = 0.65; }
  else if (m === 'SmoothPlastic') rough = 0.4;
  else if (m === 'Concrete' || m === 'Slate' || m === 'Brick' || m === 'Cobblestone' || m === 'Fabric') rough = 0.85;
  else if (m === 'Glass') rough = 0.05;
  const mat = new THREE.MeshStandardMaterial({ color: c, roughness: Math.max(0.05, rough - refl * 0.6), metalness: Math.min(1, metal + refl * 0.8),
    envMap: envTex, envMapIntensity: 0.18 + refl, transparent: p.tr > 0.01, opacity: 1 - p.tr, depthWrite: p.tr < 0.5 });
  return grime(mat, m === 'Glass' ? 0 : 0.55);
}
function partGeo(p) {
  const [sx, sy, sz] = p.size;
  const shape = p.shape.replace('Enum.PartType.', '');
  const mesh = p.mesh && p.mesh.type.replace('Enum.MeshType.', '');
  if (mesh === 'Sphere') { const g = new THREE.SphereGeometry(0.5, 24, 16); g.scale(sx, sy, sz); return g; }
  if (p.class === 'WedgePart') return wedgeGeo(sx, sy, sz);
  if (shape === 'Cylinder') { const g = new THREE.CylinderGeometry(Math.min(sy, sz) / 2, Math.min(sy, sz) / 2, sx, 28); g.rotateZ(Math.PI / 2); return g; }
  if (shape === 'Ball') return new THREE.SphereGeometry(Math.min(sx, sy, sz) / 2, 24, 16);
  return new THREE.BoxGeometry(sx, sy, sz);
}
const NORM = { Front: [0, 0, -1], Back: [0, 0, 1], Right: [1, 0, 0], Left: [-1, 0, 0], Top: [0, 1, 0], Bottom: [0, -1, 0] };
const scene = new THREE.Scene();
scene.background = new THREE.Color(q.get('bg') || '#07060c');
const K = +(q.get('k') || 1.0);
// hide= boxes "x0,y0,z0,x1,y1,z1;..." of room parts left out of the shot
const HIDE = (q.get('hide') || '').split(';').filter(Boolean).map((b) => b.split(',').map(Number));
for (const p of room.parts) {
  const [px, py, pz] = p.cf;
  if (HIDE.some((b) => px > b[0] && py > b[1] && pz > b[2] && px < b[3] && py < b[4] && pz < b[5])) continue;
  const obj = new THREE.Mesh(partGeo(p), p.tr >= 0.999 ? new THREE.MeshBasicMaterial({ visible: false }) : roomMat(p));
  obj.matrixAutoUpdate = false; obj.matrix.copy(cfMatrix(p.cf));
  obj.castShadow = p.tr < 0.5; obj.receiveShadow = true;
  for (const g of p.guis) if (!(g.face.includes('Top') && py < 1.3)) obj.add(guiPlane(p, g)); // floor stencils read backwards from here
  if (!DEPTH) for (const l of p.lights) {
    const col = new THREE.Color(`rgb(${l.c.join(',')})`);
    const face = l.face.replace('Enum.NormalId.', '');
    let L;
    if (l.cls === 'PointLight') L = new THREE.PointLight(col, l.b * K, l.range, 0);
    else {
      const n = NORM[face] || [0, -1, 0];
      L = new THREE.SpotLight(col, l.b * K * 1.6, l.range, Math.min(89, (l.cls === 'SurfaceLight' ? l.angle : l.angle / 2)) * Math.PI / 180, 0.5, 0);
      const off = faceDims(p.size, face)[2];
      L.position.set(n[0] * off, n[1] * off, n[2] * off);
      L.target.position.set(n[0] * (off + 5), n[1] * (off + 5), n[2] * (off + 5)); obj.add(L.target);
    }
    obj.add(L);
  }
  scene.add(obj);
}
// the characters: [x, y, z, yaw, scale] per character, feet on the deck
const F = 0.7;
const PLACE = {};
for (const s of (q.get('place') || 'wolf:0,84,180,1;sd:-8,101,-16,1.8;sv:8.5,99,16,1.8').split(';')) {
  const [k, v] = s.split(':'); const [x, z, yaw, sc] = v.split(',').map(Number); PLACE[k] = { x, z, yaw, sc };
}
const holders = {};
for (const k of Object.keys(PLACE)) {
  const g = await build(k);
  g.traverse((o) => { if (o.isMesh) for (const m of [].concat(o.material)) if (m.envMapIntensity !== undefined) m.envMapIntensity *= +(q.get('charEnv') || 0.3); });
  if (k === 'wolf') g.traverse((o) => { // the blades catch the light
    if (o.isMesh && o.userData.part && o.userData.part.name === 'Claw' && o.material.emissive) { o.material.emissive = new THREE.Color(0x9cc8ff); o.material.emissiveIntensity = +(q.get('clawGlow') || 0.5); }
  });
  const box = new THREE.Box3().setFromObject(g);
  g.position.y -= box.min.y;
  const h = new THREE.Group(); h.add(g);
  h.scale.setScalar(PLACE[k].sc); h.rotation.y = PLACE[k].yaw * Math.PI / 180; h.position.set(PLACE[k].x, F, PLACE[k].z);
  h.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  scene.add(h); holders[k] = h;
}
scene.updateMatrixWorld(true);
const partPos = (k, name) => { let v = null; holders[k] && holders[k].traverse((o) => { if (!v && o.userData.part && o.userData.part.name === name) v = o.getWorldPosition(new THREE.Vector3()); }); return v; };
const cam = new THREE.PerspectiveCamera(+(q.get('fov') || 42), W / H, 0.1, 400);
cam.position.copy(V3(q.get('cam') || '3.5,7.7,70.5'));
cam.lookAt(V3(q.get('look') || '0,9.7,102'));
cam.rotateZ((+(q.get('roll') || 0)) * Math.PI / 180);
cam.updateMatrixWorld();
if (DEPTH) {
  const near = 1, far = 120;
  scene.overrideMaterial = new THREE.ShaderMaterial({
    vertexShader: 'varying float vD; void main(){ vec4 mv = modelViewMatrix * vec4(position,1.0); vD = -mv.z; gl_Position = projectionMatrix * mv; }',
    fragmentShader: `varying float vD; void main(){ float d = clamp((vD - ${near.toFixed(1)}) / ${(far - near).toFixed(1)}, 0.0, 1.0); gl_FragColor = vec4(vec3(d), 1.0); }`,
  });
  scene.background = new THREE.Color(1, 1, 1);
  renderer.render(scene, cam);
  document.title = 'done';
} else {
  // -- cinematic lighting --------------------------------------------------
  scene.fog = new THREE.FogExp2(new THREE.Color(q.get('fogc') || '#1a1030'), +(q.get('fog') || 0.011));
  scene.add(new THREE.HemisphereLight(new THREE.Color(q.get('hemiSky') || '#6c5aa8'), 0x100c10, +(q.get('hemi') || 0.35)));
  const spot = (pos, at, color, power, angle, pen, shadow) => {
    const s = new THREE.SpotLight(new THREE.Color(color), power, 0, angle * Math.PI / 180, pen, 0);
    s.position.copy(V3(pos)); s.target.position.copy(V3(at)); scene.add(s.target);
    if (shadow) { s.castShadow = true; s.shadow.mapSize.set(2048, 2048); s.shadow.bias = -0.0004; s.shadow.camera.near = 2; s.shadow.camera.far = 120; }
    scene.add(s); return s;
  };
  // the pods behind the Sentinels blaze violet into the hangar and rim everyone
  spot('0,16,128', q.get('rimAt') || '0,8,80', '#8a4dff', +(q.get('rim') || 9), +(q.get('rimAng') || 30), 0.6, true);
  spot('-18,10,122', '-2,6,90', '#5b7cff', 4, 30, 0.7, false);
  spot('18,10,122', '2,6,90', '#b04dff', 4, 30, 0.7, false);
  // a hard warm work-light from over Wolverine's shoulder onto the Sentinels
  spot('-10,30,74', '0,7,100', '#ffc890', +(q.get('key') || 6), 26, 0.45, true);
  // rim lights either side behind him: teal on one shoulder, orange on the other
  const w = PLACE.wolf ? new THREE.Vector3(PLACE.wolf.x, 4.2, PLACE.wolf.z) : new THREE.Vector3(0, 4, 76);
  for (const [x, c] of [[-9, '#6fd6ff'], [9, '#ff9a40']]) {
    const s2 = new THREE.SpotLight(new THREE.Color(c), +(q.get('wrim') || 7), 0, 0.3, 0.5, 0);
    s2.position.set(w.x + x, 13, w.z + 13); s2.target.position.copy(w); scene.add(s2.target); scene.add(s2);
  }
  const warm = new THREE.PointLight(0xffb070, +(q.get('front') || 1.1), 26, 0); warm.position.set(w.x + 5, 11, w.z - 10); scene.add(warm);
  // cool fill on his back so he isn't a black cut-out
  const fill = new THREE.PointLight(0x5fa8ff, +(q.get('fill') || 1.4), 22, 0); fill.position.set(4, 9, 75); scene.add(fill);
  // alarm red from the sides
  for (const x of [-34, 34]) { const r = new THREE.PointLight(0xff2a1a, 2.2, 55, 0); r.position.set(x, 14, 96); scene.add(r); }
  // the claws glow cold, the Sentinels' cores and eyes glow hot
  for (const hand of ['RightHand', 'LeftHand']) {
    const p = partPos('wolf', hand);
    if (p) { const l = new THREE.PointLight(0xbfe0ff, 1.6, 7, 0); l.position.copy(p).add(new THREE.Vector3(0, 0, 1)); scene.add(l); }
  }
  for (const [k, c] of [['sd', 0xffb040], ['sv', 0xff3020]]) {
    const p = partPos(k, 'UpperTorso');
    if (p) { const l = new THREE.PointLight(c, 3, 16, 0); l.position.copy(p).add(new THREE.Vector3(0, 0, -2.5)); scene.add(l); }
  }
  // a big soft glow behind the standoff: the bay lit up, everyone backlit
  for (const s3 of (q.get('glow') || '').split(';').filter(Boolean)) {
    const [x, y, z, size, col, op] = s3.split(',');
    const c = document.createElement('canvas'); c.width = c.height = 256; const g = c.getContext('2d');
    const r = g.createRadialGradient(128, 128, 0, 128, 128, 128); r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(0.3, 'rgba(255,255,255,0.45)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, 256, 256);
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: new THREE.CanvasTexture(c), color: new THREE.Color(col), transparent: true, opacity: +op, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
    sp.position.set(+x, +y, +z); sp.scale.set(+size, +size * 0.8, 1); scene.add(sp);
  }
  // -- haze beams from the gantry lights ------------------------------------
  const beamTex = (() => { const c = document.createElement('canvas'); c.width = 64; c.height = 256; const g = c.getContext('2d');
    const gr = g.createLinearGradient(0, 0, 0, 256); gr.addColorStop(0, 'rgba(255,255,255,0.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 64, 256);
    const h = g.createLinearGradient(0, 0, 64, 0); h.addColorStop(0, 'rgba(0,0,0,1)'); h.addColorStop(0.5, 'rgba(0,0,0,0)'); h.addColorStop(1, 'rgba(0,0,0,1)');
    g.globalCompositeOperation = 'destination-out'; g.fillStyle = h; g.fillRect(0, 0, 64, 256);
    const t = new THREE.CanvasTexture(c); return t; })();
  const beam = (top, bottom, r0, r1, color, op) => {
    const a = V3(top), b = V3(bottom), len = a.distanceTo(b);
    const geo = new THREE.CylinderGeometry(r0, r1, len, 32, 1, true); geo.translate(0, -len / 2, 0);
    const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ map: beamTex, color: new THREE.Color(color), transparent: true, opacity: op, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false }));
    m.position.copy(a); m.quaternion.setFromUnitVectors(new THREE.Vector3(0, -1, 0), b.clone().sub(a).normalize()); scene.add(m);
  };
  for (const s of (q.get('beams') || '-16,23,118,-16,0.8,112,0.6,5,#a070ff,0.18;16,23,118,16,0.8,112,0.6,5,#a070ff,0.18;-6,32,78,-2,0.8,96,0.8,8,#ffcf9a,0.1').split(';')) {
    const v = s.split(','); beam(v.slice(0, 3).join(','), v.slice(3, 6).join(','), +v[6], +v[7], v[8], +v[9]);
  }
  // -- sparks and embers drifting between them, dust in the light -----------
  let seed = 11; const rnd = (a = 0, b = 1) => { seed = (seed * 16807) % 2147483647; return a + ((seed - 1) / 2147483646) * (b - a); };
  const dot = (() => { const c = document.createElement('canvas'); c.width = c.height = 64; const g = c.getContext('2d');
    const r = g.createRadialGradient(32, 32, 0, 32, 32, 32); r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(0.25, 'rgba(255,255,255,0.6)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, 64, 64); return new THREE.CanvasTexture(c); })();
  const cloud = (n, box, size, color, op) => {
    const pos = [];
    for (let i = 0; i < n; i++) pos.push(rnd(box[0], box[3]), rnd(box[1], box[4]), rnd(box[2], box[5]));
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    scene.add(new THREE.Points(g, new THREE.PointsMaterial({ map: dot, size, color: new THREE.Color(color), transparent: true, opacity: op, blending: THREE.AdditiveBlending, depthWrite: false, sizeAttenuation: true, fog: false })));
  };
  cloud(+(q.get('embers') || 140), [-14, 1, 76, 14, 16, 100], 0.22, '#ffa040', 0.9);
  cloud(90, [-12, 1, 78, 12, 14, 100], 0.12, '#ffe0a0', 1);
  cloud(260, [-30, 1, 76, 30, 24, 124], 0.14, '#b8a0ff', 0.35);
  // spark streaks off the claws and the Sentinels' armour
  const streaks = [];
  const hands = [partPos('wolf', 'RightHand'), partPos('wolf', 'LeftHand')].filter(Boolean);
  for (let i = 0; i < +(q.get('sparks') || 60) && hands.length; i++) {
    const o = hands[i % hands.length].clone().add(new THREE.Vector3(rnd(-0.8, 0.8), rnd(-0.6, 1.2), rnd(0, 1.4)));
    const d = new THREE.Vector3(rnd(-1, 1), rnd(-0.2, 1.2), rnd(0.2, 1.4)).normalize().multiplyScalar(rnd(0.5, 2.4));
    streaks.push(o.x, o.y, o.z, o.x + d.x, o.y + d.y, o.z + d.z);
  }
  const sg = new THREE.BufferGeometry(); sg.setAttribute('position', new THREE.Float32BufferAttribute(streaks, 3));
  scene.add(new THREE.LineSegments(sg, new THREE.LineBasicMaterial({ color: new THREE.Color(3, 2.2, 1.2), transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false, fog: false })));

  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, cam));
  composer.addPass(new UnrealBloomPass(new THREE.Vector2(W, H), +(q.get('bloom') || 0.9), +(q.get('bloomR') || 0.55), +(q.get('bloomAt') || 0.8)));
  composer.addPass(new OutputPass());
  composer.render();
  document.title = 'done';
}
