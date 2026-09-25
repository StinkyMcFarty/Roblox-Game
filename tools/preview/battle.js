// fx=battle: effects for the Verity battle thumbnail, built around the posed
// models (built[0] = Wolverine, built[1] = Sentinel). Everything is placed from
// the models' actual part positions: the clash happens where his striking
// claws meet the Sentinel's guard, the death ray charges in its cocked fist.
let seed = 7;
const rand = (a = 0, b = 1) => {
  seed = (seed * 16807) % 2147483647;
  return a + ((seed - 1) / 2147483646) * (b - a);
};

function canvasTex(THREE, w, h, draw) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

export function battleFx(THREE, scene, cam, built, q) {
  const W = +(q.get('w') || 1920), H = +(q.get('h') || 1080);
  const V = (x, y, z) => new THREE.Vector3(x, y, z);

  // -- textures ---------------------------------------------------------------
  const glowTex = canvasTex(THREE, 256, 256, (g, w, h) => {
    const r = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
    r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(0.15, 'rgba(255,255,255,0.8)');
    r.addColorStop(0.4, 'rgba(255,255,255,0.25)'); r.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = r; g.fillRect(0, 0, w, h);
  });
  const streakTex = canvasTex(THREE, 256, 32, (g, w, h) => {
    // bright head on the right, tail fading to the left
    const x = g.createLinearGradient(0, 0, w, 0);
    x.addColorStop(0, 'rgba(255,255,255,0)'); x.addColorStop(0.75, 'rgba(255,255,255,0.8)'); x.addColorStop(1, 'rgba(255,255,255,1)');
    g.fillStyle = x; g.fillRect(0, 0, w, h);
    const y = g.createLinearGradient(0, 0, 0, h);
    y.addColorStop(0, 'rgba(0,0,0,1)'); y.addColorStop(0.5, 'rgba(0,0,0,0)'); y.addColorStop(1, 'rgba(0,0,0,1)');
    g.globalCompositeOperation = 'destination-out'; g.fillStyle = y; g.fillRect(0, 0, w, h);
  });
  const smokeTex = canvasTex(THREE, 256, 256, (g, w, h) => {
    for (let i = 0; i < 26; i++) {
      const x = w / 2 + (rand() - 0.5) * w * 0.45, y = h / 2 + (rand() - 0.5) * h * 0.45, r = w * (0.12 + rand() * 0.2);
      const gr = g.createRadialGradient(x, y, 0, x, y, r);
      gr.addColorStop(0, 'rgba(255,255,255,0.22)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
      g.fillStyle = gr; g.fillRect(0, 0, w, h);
    }
  });

  const add = (o) => { scene.add(o); return o; };
  const hdr = (hex, k) => new THREE.Color(hex).multiplyScalar(k);

  function glow(pos, size, color, opacity = 1) {
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, color, transparent: true, opacity, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
    s.position.copy(pos); s.scale.set(size, size, 1);
    return add(s);
  }
  // a camera-facing streak from p0 (tail) to p1 (head)
  function streak(p0, p1, width, color, opacity = 1, tex = streakTex, blending = THREE.AdditiveBlending) {
    const a = p0.clone().project(cam), b = p1.clone().project(cam);
    const dx = (b.x - a.x) * W / 2, dy = (b.y - a.y) * H / 2;
    const mid = p0.clone().add(p1).multiplyScalar(0.5);
    const dist = mid.distanceTo(cam.position);
    const wpp = (2 * Math.tan((cam.fov * Math.PI) / 360) * dist) / H; // world units per pixel at that depth
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, color, transparent: true, opacity, blending, depthWrite: false, toneMapped: false, rotation: Math.atan2(dy, dx) }));
    s.position.copy(mid);
    s.scale.set(Math.max(0.01, Math.hypot(dx, dy) * wpp), width, 1);
    return add(s);
  }
  function ribbon(points, widths, colors, alphas) {
    // triangle strip facing the camera along a polyline
    const pos = [], col = [];
    for (let i = 0; i < points.length; i++) {
      const p = points[i];
      const t = (points[Math.min(i + 1, points.length - 1)].clone().sub(points[Math.max(i - 1, 0)])).normalize();
      const toCam = cam.position.clone().sub(p).normalize();
      const side = t.clone().cross(toCam).normalize().multiplyScalar(widths[i] / 2);
      for (const sgn of [1, -1]) {
        const v = p.clone().addScaledVector(side, sgn);
        pos.push(v.x, v.y, v.z);
        const c = colors[i];
        col.push(c.r * alphas[i], c.g * alphas[i], c.b * alphas[i]);
      }
    }
    const idx = [];
    for (let i = 0; i < points.length - 1; i++) {
      const a = i * 2;
      idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
    g.setIndex(idx);
    return add(new THREE.Mesh(g, new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, toneMapped: false })));
  }
  function bolt(a, b, jag, radius, color) {
    const pts = [a.clone()];
    const n = 9;
    for (let i = 1; i < n; i++) {
      const p = a.clone().lerp(b, i / n);
      p.add(V(rand(-jag, jag), rand(-jag, jag), rand(-jag, jag)));
      pts.push(p);
    }
    pts.push(b.clone());
    const curve = new THREE.CatmullRomCurve3(pts, false, 'catmullrom', 0.1);
    const mesh = new THREE.Mesh(new THREE.TubeGeometry(curve, 40, radius, 5, false),
      new THREE.MeshBasicMaterial({ color, toneMapped: false }));
    return add(mesh);
  }

  // -- find the parts ---------------------------------------------------------
  const parts = (group, test) => {
    const out = [];
    group.traverse((o) => { if (o.isMesh && o.userData.part && test(o.userData.part)) out.push(o); });
    return out;
  };
  const wpos = (o) => o.getWorldPosition(new THREE.Vector3());
  const [wolv, sent] = built;
  const wHand = { L: wpos(parts(wolv, (p) => p.name === 'LeftHand')[0]), R: wpos(parts(wolv, (p) => p.name === 'RightHand')[0]) };
  const tips = parts(wolv, (p) => p.name === 'Claw' && p.cls === 'WedgePart').map(wpos);
  const strikeTips = tips.filter((t) => t.distanceTo(wHand.L) < t.distanceTo(wHand.R));
  const raisedTips = tips.filter((t) => t.distanceTo(wHand.L) >= t.distanceTo(wHand.R));
  const sHand = { L: wpos(parts(sent, (p) => p.name === 'LeftHand')[0]), R: wpos(parts(sent, (p) => p.name === 'RightHand')[0]) };
  const sGuard = wpos(parts(sent, (p) => p.name === 'RightLowerArm')[0]);
  const wTorso = wpos(parts(wolv, (p) => p.name === 'UpperTorso')[0]);
  const sTorso = wpos(parts(sent, (p) => p.name === 'UpperTorso')[0]);
  const sFootL = wpos(parts(sent, (p) => p.name === 'LeftFoot')[0]);
  const sFootR = wpos(parts(sent, (p) => p.name === 'RightFoot')[0]);

  const tipMid = strikeTips.reduce((a, b) => a.add(b), V(0, 0, 0)).multiplyScalar(1 / Math.max(1, strikeTips.length));
  const clash = tipMid.clone().lerp(sGuard, 0.35);
  const fwd = sTorso.clone().sub(wTorso).setY(0).normalize(); // his line of attack
  const up = V(0, 1, 0);

  // -- the clash: flash, star, sparks, molten drops ----------------------------
  glow(clash, 4.2, hdr(0xffc860, 1.3), 0.8);
  glow(clash, 1.6, hdr(0xffffff, 2.6), 1);
  glow(clash, 8, hdr(0xff7a20, 0.5), 0.35);
  for (let i = 0; i < 6; i++) { // star spikes
    const a = (i / 6) * Math.PI + 0.35;
    const d = cam.matrixWorld.elements;
    const right = V(d[0], d[1], d[2]), camUp = V(d[4], d[5], d[6]);
    const dir = right.multiplyScalar(Math.cos(a)).add(camUp.multiplyScalar(Math.sin(a)));
    const len = i % 3 === 0 ? 4.2 : 2;
    streak(clash.clone().addScaledVector(dir, -len), clash.clone().addScaledVector(dir, len), i % 3 === 0 ? 0.14 : 0.08, hdr(0xfff0c0, 2.2), 0.85);
  }
  const clashLight = new THREE.PointLight(0xffb040, 45, 16, 2);
  clashLight.position.copy(clash); add(clashLight);
  for (let i = 0; i < 90; i++) {
    // sprayed back toward him, up and out, never into the Sentinel
    const dir = V(rand(-1, 1), rand(-0.3, 1.2), rand(-1, 0.6)).addScaledVector(fwd, -1.1).normalize();
    const dist = rand(0.6, 5.5);
    const fall = dist * dist * 0.06;
    const head = clash.clone().addScaledVector(dir, dist).add(V(0, -fall, 0));
    const tail = clash.clone().addScaledVector(dir, Math.max(0, dist - rand(0.5, 1.8))).add(V(0, -fall * 0.6, 0));
    const hot = rand();
    const color = hot > 0.7 ? hdr(0xffffff, 3) : hot > 0.3 ? hdr(0xffc040, 2.4) : hdr(0xff6a10, 2);
    streak(tail, head, rand(0.03, 0.07), color, rand(0.55, 0.95));
  }
  for (let i = 0; i < 24; i++) { // molten drops falling from the cut
    glow(clash.clone().add(V(rand(-1.5, 1.5), rand(-4.5, -0.5), rand(-1.5, 1))), rand(0.12, 0.3), hdr(0xffa030, 2.2), 0.9);
  }

  // -- slash trails: the arc the striking claws just carved, and a fainter one
  // behind the claws he's winding up ------------------------------------------
  const arc = (tip, from, bend, widthMax, col, alpha) => {
    const pts = [], ws = [], cs = [], as = [];
    const ctrl = tip.clone().lerp(from, 0.5).add(bend);
    const N = 26;
    for (let i = 0; i <= N; i++) {
      const t = i / N;
      const p = from.clone().multiplyScalar((1 - t) * (1 - t)).add(ctrl.clone().multiplyScalar(2 * (1 - t) * t)).add(tip.clone().multiplyScalar(t * t));
      pts.push(p);
      ws.push(widthMax * Math.pow(t, 1.3) * (1 - 0.15 * t));
      cs.push(col.clone().lerp(hdr(0xffffff, 3), t * t));
      as.push(alpha * Math.pow(t, 0.9));
    }
    ribbon(pts, ws, cs, as);
  };
  for (const tip of strikeTips) {
    arc(tip, tip.clone().addScaledVector(fwd, -4.5).add(V(0, 4, 0)), V(0, 1.4, 0).addScaledVector(fwd, -1), 0.4, hdr(0xffcf30, 1.4), 0.85);
  }
  for (const tip of raisedTips) {
    arc(tip, tip.clone().addScaledVector(fwd, -2.5).add(V(0, -3.5, 0)), V(0, -0.6, 0).addScaledVector(fwd, -1.5), 0.3, hdr(0xffcf30, 1.2), 0.45);
  }

  // -- death ray charging in the cocked fist -----------------------------------
  // just off the knuckles of the raised fist, toward the camera so the
  // gauntlet doesn't hide it
  const orb = sHand.L.clone().add(V(0, 1.9, 0)).addScaledVector(cam.position.clone().sub(sHand.L).normalize(), 1.4);
  glow(orb, 5, hdr(0xff28c8, 1.1), 0.75);
  glow(orb, 2.4, hdr(0x5ae1ff, 1.6), 0.9);
  glow(orb, 1.1, hdr(0xffffff, 3), 1);
  const orbLight = new THREE.PointLight(0xd23cff, 30, 12, 2);
  orbLight.position.copy(orb); add(orbLight);
  for (let i = 0; i < 9; i++) {
    const end = orb.clone().add(V(rand(-1, 1), rand(-1, 1), rand(-1, 1)).normalize().multiplyScalar(rand(1.4, 3.2)));
    bolt(orb, end, 0.3, rand(0.02, 0.04), i % 2 ? hdr(0x96f0ff, 2.2) : hdr(0xff6eeb, 2.2));
  }
  for (let i = 0; i < 30; i++) { // particles being sucked into the charge
    const d = V(rand(-1, 1), rand(-1, 1), rand(-1, 1)).normalize();
    const r = rand(1.5, 4);
    streak(orb.clone().addScaledVector(d, r), orb.clone().addScaledVector(d, r - rand(0.4, 1)), 0.05, hdr(0xff8cf0, 2), 0.8);
  }

  // -- the Sentinel's weight: floor cracks, dust, debris ------------------------
  const floorY = 0.03;
  const crackAt = (c, n, len) => {
    for (let i = 0; i < n; i++) {
      let p = V(c.x, floorY, c.z), a = rand(0, Math.PI * 2);
      for (let k = 0; k < 6; k++) {
        a += rand(-0.6, 0.6);
        const q2 = p.clone().add(V(Math.cos(a), 0, Math.sin(a)).multiplyScalar(len * rand(0.4, 1)));
        const seg = new THREE.Mesh(new THREE.PlaneGeometry(p.distanceTo(q2), 0.12 - k * 0.012), new THREE.MeshBasicMaterial({ color: hdr(0xff6a18, 1.4 - k * 0.18), toneMapped: false, transparent: true, opacity: 0.95 }));
        seg.rotation.x = -Math.PI / 2;
        seg.rotation.z = -Math.atan2(q2.z - p.z, q2.x - p.x);
        seg.position.copy(p.clone().lerp(q2, 0.5)).setY(floorY + k * 0.001);
        add(seg);
        const dark = seg.clone(); dark.material = new THREE.MeshBasicMaterial({ color: 0x050505 });
        dark.scale.set(1.02, 2.4, 1); dark.position.y -= 0.005; add(dark);
        p = q2;
      }
    }
  };
  crackAt(sFootR, 7, 1.1);
  crackAt(sFootL, 5, 0.9);
  for (const f of [sFootL, sFootR]) glow(V(f.x, 0.3, f.z), 3, hdr(0xff5a10, 0.6), 0.5);
  for (let i = 0; i < 26; i++) { // dust kicked up round his feet
    const base = (i % 2 ? sFootL : sFootR);
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: smokeTex, color: new THREE.Color(0x8a8078), transparent: true, opacity: rand(0.35, 0.7), depthWrite: false, rotation: rand(0, 6.28) }));
    s.position.set(base.x + rand(-3.5, 3.5), rand(0.3, 1.6), base.z + rand(-2.5, 2.5));
    const k = rand(1.8, 4); s.scale.set(k, k, 1); add(s);
  }
  const chunkMat = new THREE.MeshStandardMaterial({ color: 0x3a3a40, roughness: 0.9 });
  for (let i = 0; i < 26; i++) { // chunks of floor thrown up
    const base = (i % 2 ? sFootL : sFootR);
    const c = new THREE.Mesh(new THREE.BoxGeometry(rand(0.15, 0.5), rand(0.1, 0.35), rand(0.15, 0.45)), chunkMat);
    c.position.set(base.x + rand(-3, 3), rand(0.4, 4.5), base.z + rand(-2, 2));
    c.rotation.set(rand(0, 6), rand(0, 6), rand(0, 6));
    c.castShadow = true; add(c);
    streak(c.position.clone().add(V(0, -rand(0.4, 1), 0)), c.position.clone(), 0.06, new THREE.Color(0x9a9088), 0.35, streakTex, THREE.NormalBlending);
  }

  // -- his speed: lines streaming off behind him -------------------------------
  for (let i = 0; i < 12; i++) {
    const o = wTorso.clone().add(V(rand(-2, 2), rand(-2.2, 2.2), rand(-2, 2))).addScaledVector(fwd, -rand(1, 3));
    streak(o.clone().addScaledVector(fwd, -rand(3, 6)).add(V(0, rand(1, 2), 0)), o, rand(0.02, 0.05), hdr(0xfff4d8, 1), rand(0.15, 0.35));
  }

  // -- atmosphere: embers and light shafts ------------------------------------
  for (let i = 0; i < 90; i++) {
    const p = V(rand(-18, 18), rand(0.5, 16), rand(-8, 14));
    glow(p, rand(0.08, 0.22), rand() > 0.3 ? hdr(0xff9030, 2) : hdr(0xffe080, 2), rand(0.4, 1));
  }
  const shaftTex = canvasTex(THREE, 64, 256, (g, w, h) => {
    const y = g.createLinearGradient(0, 0, 0, h);
    y.addColorStop(0, 'rgba(255,220,160,0.55)'); y.addColorStop(1, 'rgba(255,220,160,0)');
    g.fillStyle = y; g.fillRect(0, 0, w, h);
    const x = g.createLinearGradient(0, 0, w, 0);
    x.addColorStop(0, 'rgba(0,0,0,1)'); x.addColorStop(0.5, 'rgba(0,0,0,0)'); x.addColorStop(1, 'rgba(0,0,0,1)');
    g.globalCompositeOperation = 'destination-out'; g.fillStyle = x; g.fillRect(0, 0, w, h);
  });
  for (const x of (q.get('shafts') || '-14,-2,10').split(',').map(Number)) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(6, 22), new THREE.MeshBasicMaterial({ map: shaftTex, transparent: true, opacity: 0.45, blending: THREE.AdditiveBlending, depthWrite: false }));
    m.position.set(x, 11, 12); m.rotation.set(0, Math.PI, rand(-0.25, 0.25)); add(m);
  }
}
