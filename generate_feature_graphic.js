const fs = require('fs');
const zlib = require('zlib');
const path = require('path');

// CRC32 table
function crc32(buf) {
  let table = new Int32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    table[i] = c;
  }
  let crc = -1;
  for (let i = 0; i < buf.length; i++) crc = table[(crc ^ buf[i]) & 0xFF] ^ (crc >>> 8);
  return (crc ^ -1) >>> 0;
}

// Pure Node.js PNG encoder for arbitrary dimensions
function encodePNG(width, height, rgbaBuffer) {
  const rowLen = width * 4;
  const filtered = Buffer.alloc(height * (rowLen + 1));
  for (let y = 0; y < height; y++) {
    filtered[y * (rowLen + 1)] = 0; // Filter None
    rgbaBuffer.copy(filtered, y * (rowLen + 1) + 1, y * rowLen, (y + 1) * rowLen);
  }
  const idatData = zlib.deflateSync(filtered, { level: 9 });

  function makeChunk(type, data) {
    const len = data.length;
    const buf = Buffer.alloc(12 + len);
    buf.writeUInt32BE(len, 0);
    buf.write(type, 4, 4, 'ascii');
    data.copy(buf, 8);
    const crc = crc32(buf.subarray(4, 8 + len));
    buf.writeUInt32BE(crc, 8 + len);
    return buf;
  }

  const header = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdrData = Buffer.alloc(13);
  ihdrData.writeUInt32BE(width, 0);
  ihdrData.writeUInt32BE(height, 4);
  ihdrData[8] = 8;
  ihdrData[9] = 6; // RGBA
  ihdrData[10] = 0;
  ihdrData[11] = 0;
  ihdrData[12] = 0;

  return Buffer.concat([
    header,
    makeChunk('IHDR', ihdrData),
    makeChunk('IDAT', idatData),
    makeChunk('IEND', Buffer.alloc(0))
  ]);
}

// 2D High precision rendering canvas
class BannerCanvas {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.buf = Buffer.alloc(w * h * 4, 0);
  }

  setPixel(x, y, r, g, b, a = 1.0) {
    x = Math.round(x);
    y = Math.round(y);
    if (x < 0 || x >= this.w || y < 0 || y >= this.h || a <= 0.001) return;
    const idx = (y * this.w + x) * 4;
    const sa = Math.min(1.0, Math.max(0.0, a));
    const da = this.buf[idx + 3] / 255.0;
    const outA = sa + da * (1.0 - sa);
    if (outA <= 0.001) return;

    const sr = r * sa;
    const sg = g * sa;
    const sb = b * sa;
    const dr = (this.buf[idx] / 255.0) * da * (1.0 - sa);
    const dg = (this.buf[idx + 1] / 255.0) * da * (1.0 - sa);
    const db = (this.buf[idx + 2] / 255.0) * da * (1.0 - sa);

    this.buf[idx] = Math.min(255, Math.max(0, Math.round(((sr + dr) / outA) * 255)));
    this.buf[idx + 1] = Math.min(255, Math.max(0, Math.round(((sg + dg) / outA) * 255)));
    this.buf[idx + 2] = Math.min(255, Math.max(0, Math.round(((sb + db) / outA) * 255)));
    this.buf[idx + 3] = Math.min(255, Math.max(0, Math.round(outA * 255)));
  }

  drawRadialGlow(cx, cy, r, color, maxAlpha = 1.0, falloff = 2.0) {
    const x0 = Math.max(0, Math.floor(cx - r));
    const x1 = Math.min(this.w - 1, Math.ceil(cx + r));
    const y0 = Math.max(0, Math.floor(cy - r));
    const y1 = Math.min(this.h - 1, Math.ceil(cy + r));
    const r2 = r * r;

    for (let y = y0; y <= y1; y++) {
      const dy = y - cy;
      for (let x = x0; x <= x1; x++) {
        const dx = x - cx;
        const d2 = dx * dx + dy * dy;
        if (d2 < r2) {
          const dNorm = Math.sqrt(d2) / r;
          const a = maxAlpha * Math.pow(Math.max(0.0, 1.0 - dNorm), falloff);
          if (a > 0.002) {
            this.setPixel(x, y, color[0], color[1], color[2], a);
          }
        }
      }
    }
  }

  drawCircle(cx, cy, radius, color, feather = 1.0) {
    const x0 = Math.max(0, Math.floor(cx - radius - feather));
    const x1 = Math.min(this.w - 1, Math.ceil(cx + radius + feather));
    const y0 = Math.max(0, Math.floor(cy - radius - feather));
    const y1 = Math.min(this.h - 1, Math.ceil(cy + radius + feather));

    for (let y = y0; y <= y1; y++) {
      const dy = y - cy;
      for (let x = x0; x <= x1; x++) {
        const dx = x - cx;
        const dist = Math.sqrt(dx * dx + dy * dy);
        const delta = dist - radius;
        if (delta <= feather) {
          const a = delta <= 0 ? 1.0 : (1.0 - delta / feather);
          this.setPixel(x, y, color[0], color[1], color[2], (color[3] || 1.0) * a);
        }
      }
    }
  }

  drawLine(x0, y0, x1, y1, width, color) {
    const dx = x1 - x0;
    const dy = y1 - y0;
    const len = Math.sqrt(dx * dx + dy * dy);
    if (len === 0) return;
    const hw = width * 0.5;

    const minX = Math.max(0, Math.floor(Math.min(x0, x1) - hw - 1));
    const maxX = Math.min(this.w - 1, Math.ceil(Math.max(x0, x1) + hw + 1));
    const minY = Math.max(0, Math.floor(Math.min(y0, y1) - hw - 1));
    const maxY = Math.min(this.h - 1, Math.ceil(Math.max(y0, y1) + hw + 1));

    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        const t = ((x - x0) * dx + (y - y0) * dy) / (len * len);
        const clampedT = Math.max(0.0, Math.min(1.0, t));
        const px = x0 + clampedT * dx;
        const py = y0 + clampedT * dy;
        const dist = Math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
        if (dist <= hw + 0.8) {
          const a = dist <= hw ? 1.0 : (1.0 - (dist - hw) / 0.8);
          this.setPixel(x, y, color[0], color[1], color[2], (color[3] || 1.0) * a);
        }
      }
    }
  }

  drawPolygon(points, color) {
    let minX = this.w, maxX = 0, minY = this.h, maxY = 0;
    for (const p of points) {
      if (p[0] < minX) minX = p[0];
      if (p[0] > maxX) maxX = p[0];
      if (p[1] < minY) minY = p[1];
      if (p[1] > maxY) maxY = p[1];
    }
    minX = Math.max(0, Math.floor(minX - 1));
    maxX = Math.min(this.w - 1, Math.ceil(maxX + 1));
    minY = Math.max(0, Math.floor(minY - 1));
    maxY = Math.min(this.h - 1, Math.ceil(maxY + 1));

    function pointInPoly(x, y) {
      let inside = false;
      for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
        const xi = points[i][0], yi = points[i][1];
        const xj = points[j][0], yj = points[j][1];
        const intersect = ((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
        if (intersect) inside = !inside;
      }
      return inside;
    }

    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        let count = 0;
        if (pointInPoly(x - 0.25, y - 0.25)) count++;
        if (pointInPoly(x + 0.25, y - 0.25)) count++;
        if (pointInPoly(x - 0.25, y + 0.25)) count++;
        if (pointInPoly(x + 0.25, y + 0.25)) count++;
        if (count > 0) {
          this.setPixel(x, y, color[0], color[1], color[2], (color[3] || 1.0) * (count / 4.0));
        }
      }
    }
  }
}

// Render the 1024x500 Feature Graphic
function generateFeatureGraphic() {
  const W = 1024;
  const H = 500;
  const canvas = new BannerCanvas(W, H);

  console.log('Rendering 1024x500 Feature Graphic background...');
  // 1. Rich Deep Cyan/Navy Gradient Background with Vignette
  for (let y = 0; y < H; y++) {
    const ny = y / H;
    for (let x = 0; x < W; x++) {
      const nx = x / W;
      // Dual focal points: left (bulb at x=240, y=240), right (title glow at x=680, y=240)
      const dx1 = (x - 240) / 450;
      const dy1 = (y - 240) / 280;
      const d1 = Math.sqrt(dx1 * dx1 + dy1 * dy1);

      const dx2 = (x - 680) / 550;
      const dy2 = (y - 250) / 280;
      const d2 = Math.sqrt(dx2 * dx2 + dy2 * dy2);

      const glowStrength = Math.max(0, 1.0 - Math.min(d1, d2));

      // Color transition: dark blue void -> vibrant royal circuit navy -> cyber teal hints
      const r = (3 * (1 - glowStrength) + 12 * glowStrength) / 255;
      const g = (10 * (1 - glowStrength) + 38 * glowStrength) / 255;
      const b = (26 * (1 - glowStrength) + 82 * glowStrength) / 255;

      canvas.setPixel(x, y, r, g, b, 1.0);
    }
  }

  // 2. High-Tech Cyber Perspective Grid
  for (let x = 0; x <= W; x += 48) {
    canvas.drawLine(x, 0, x, H, 1.0, [0.0, 0.5, 0.85, 0.08]);
  }
  for (let y = 0; y <= H; y += 48) {
    canvas.drawLine(0, y, W, y, 1.0, [0.0, 0.5, 0.85, 0.08]);
  }

  // 3. Dynamic Circuit Traces running across the entire banner
  console.log('Drawing interconnecting circuit pathways...');
  const neonCyan = [0.0, 0.95, 1.0, 0.95];
  const neonGold = [1.0, 0.85, 0.2, 1.0];

  const traces = [
    // Top feeder into bulb
    [[240, 20], [240, 95]],
    // Bottom feeder from bulb
    [[240, 480], [240, 395]],
    // Left edge into bulb
    [[20, 160], [110, 160], [150, 200]],
    [[20, 300], [110, 300], [150, 260]],
    // Main power conduit connecting bulb to Title
    [[330, 230], [390, 230], [430, 190], [530, 190]],
    [[330, 260], [390, 260], [430, 300], [530, 300]],
    // Traces framing Title area
    [[530, 140], [780, 140], [820, 180], [990, 180]],
    [[530, 350], [780, 350], [820, 310], [990, 310]],
    [[990, 245], [910, 245], [880, 215]],
    // Corner accent circuits
    [[50, 50], [120, 50], [150, 80]],
    [[980, 50], [900, 50], [870, 80]],
    [[50, 450], [120, 450], [150, 420]],
    [[980, 450], [900, 450], [870, 420]]
  ];

  for (const poly of traces) {
    for (let i = 0; i < poly.length - 1; i++) {
      const p0 = poly[i];
      const p1 = poly[i + 1];
      // Glow blur underlay
      canvas.drawLine(p0[0], p0[1], p1[0], p1[1], 12.0, [0.0, 0.7, 1.0, 0.35]);
      // Sharp core trace
      canvas.drawLine(p0[0], p0[1], p1[0], p1[1], 4.5, neonCyan);
      // Hot center
      canvas.drawLine(p0[0], p0[1], p1[0], p1[1], 1.5, [0.85, 1.0, 1.0, 0.95]);
    }
  }

  // Golden Terminal Connection Pads
  const terminals = [
    [20, 160], [20, 300], [240, 20], [240, 480],
    [430, 190], [430, 300], [530, 140], [530, 350],
    [990, 180], [990, 310], [990, 245],
    [50, 50], [980, 50], [50, 450], [980, 450]
  ];

  for (const pt of terminals) {
    canvas.drawRadialGlow(pt[0], pt[1], 18, [1.0, 0.8, 0.1], 0.75, 1.8);
    canvas.drawCircle(pt[0], pt[1], 7.5, [0.0, 0.25, 0.45, 0.9]);
    canvas.drawCircle(pt[0], pt[1], 5.5, neonGold);
    canvas.drawCircle(pt[0], pt[1], 2.5, [1.0, 1.0, 0.9, 1.0]);
  }

  // 4. THE PROMINENT BULB (Left Hero Element at x=240, y=240)
  console.log('Rendering 3D glowing circuit bulb...');
  const bx = 240;
  const by = 240;

  // Massive radiant bloom
  canvas.drawRadialGlow(bx, by, 220, [0.0, 0.85, 1.0], 0.38, 1.7);
  canvas.drawRadialGlow(bx, by, 140, [1.0, 0.85, 0.2], 0.65, 1.8);
  canvas.drawRadialGlow(bx, by, 70, [1.0, 1.0, 0.8], 0.95, 2.0);

  // Outer Bulb Glass Envelope
  const bulbPoints = [];
  const segments = 48;
  for (let i = 0; i <= segments; i++) {
    const angle = Math.PI * 0.18 + (i / segments) * (Math.PI * 1.64);
    const r = 105;
    const px = bx + Math.cos(angle) * r;
    const py = by - Math.sin(angle) * r;
    bulbPoints.push([px, py]);
  }
  bulbPoints.push([bx + 54, by + 104]);
  bulbPoints.push([bx + 54, by + 120]);
  bulbPoints.push([bx - 54, by + 120]);
  bulbPoints.push([bx - 54, by + 104]);

  // Dark tinted glass body
  canvas.drawPolygon(bulbPoints, [0.02, 0.14, 0.28, 0.55]);

  // Glass neon outline
  for (let i = 0; i < bulbPoints.length - 1; i++) {
    canvas.drawLine(bulbPoints[i][0], bulbPoints[i][1], bulbPoints[i + 1][0], bulbPoints[i + 1][1], 6.0, [0.3, 0.9, 1.0, 0.9]);
    canvas.drawLine(bulbPoints[i][0], bulbPoints[i][1], bulbPoints[i + 1][0], bulbPoints[i + 1][1], 2.0, [0.9, 1.0, 1.0, 1.0]);
  }

  // Glass Specular Highlight Arc
  for (let a = 2.1; a <= 2.9; a += 0.03) {
    const hx = bx + Math.cos(a) * 88;
    const hy = by - Math.sin(a) * 88;
    canvas.drawCircle(hx, hy, 5.0, [1.0, 1.0, 1.0, 0.8]);
  }

  // Brass Base Segments
  function drawBaseSegment(yOffset, w, h) {
    const x0 = bx - w * 0.5;
    const x1 = bx + w * 0.5;
    const y0 = by + yOffset;
    const y1 = y0 + h;
    for (let cy = y0; cy <= y1; cy++) {
      for (let cx = x0; cx <= x1; cx++) {
        const u = (cx - x0) / ((x1 - x0) || 1);
        let col;
        if (u < 0.25) col = [0.6, 0.42, 0.1, 1.0];
        else if (u < 0.65) col = [1.0, 0.95, 0.65, 1.0];
        else col = [0.9, 0.72, 0.18, 1.0];
        canvas.setPixel(cx, cy, col[0], col[1], col[2], 1.0);
      }
    }
    canvas.drawLine(x0, y0, x1, y0, 1.5, [1.0, 0.95, 0.7, 1.0]);
    canvas.drawLine(x0, y1, x1, y1, 1.5, [0.5, 0.35, 0.08, 1.0]);
  }

  drawBaseSegment(120, 110, 15);
  drawBaseSegment(135, 102, 14);
  drawBaseSegment(149, 90, 14);

  // Ceramic base & Silver contact
  canvas.drawCircle(bx, by + 168, 20, [0.12, 0.12, 0.14, 1.0]);
  canvas.drawCircle(bx, by + 168, 10, [0.85, 0.92, 0.98, 1.0]);

  // Plasma Lightning Bolt Filament inside Bulb
  const boltOuter = [
    [bx + 14, by - 80],
    [bx - 55, by + 6],
    [bx - 7, by + 10],
    [bx - 50, by + 94],
    [bx + 54, by - 4],
    [bx + 4, by - 8],
    [bx + 36, by - 80]
  ];

  canvas.drawRadialGlow(bx, by + 8, 85, [1.0, 0.85, 0.2], 0.95, 1.8);
  canvas.drawRadialGlow(bx, by + 8, 40, [1.0, 1.0, 1.0], 1.0, 2.0);
  canvas.drawPolygon(boltOuter, [1.0, 0.84, 0.15, 1.0]);

  const boltInner = [
    [bx + 13, by - 72],
    [bx - 42, by + 4],
    [bx - 5, by + 8],
    [bx - 36, by + 82],
    [bx + 44, by - 2],
    [bx + 6, by - 6],
    [bx + 31, by - 72]
  ];
  canvas.drawPolygon(boltInner, [1.0, 1.0, 0.92, 1.0]);

  for (let i = 0; i < boltOuter.length; i++) {
    const p0 = boltOuter[i];
    const p1 = boltOuter[(i + 1) % boltOuter.length];
    canvas.drawLine(p0[0], p0[1], p1[0], p1[1], 3.5, [1.0, 0.95, 0.65, 1.0]);
  }

  // Floating Electrical Energy Spark Particles
  const sparks = [
    [bx - 90, by - 40, 5.5, [1.0, 1.0, 1.0]],
    [bx + 90, by - 35, 5.0, [1.0, 1.0, 1.0]],
    [bx - 80, by + 60, 4.5, [0.0, 0.9, 1.0]],
    [bx + 80, by + 55, 6.0, [1.0, 0.9, 0.3]],
    [bx, by - 140, 6.5, [1.0, 0.95, 0.4]],
    [bx - 130, by + 12, 4.5, [0.0, 1.0, 0.8]],
    [bx + 135, by + 8, 4.5, [0.0, 1.0, 0.8]],
    [480, 220, 5.0, [0.0, 0.95, 1.0]],
    [510, 270, 4.0, [1.0, 0.85, 0.2]],
    [880, 190, 5.0, [0.0, 0.95, 1.0]],
    [840, 280, 4.5, [1.0, 0.9, 0.3]]
  ];

  for (const sp of sparks) {
    canvas.drawRadialGlow(sp[0], sp[1], sp[2] * 4, sp[3], 0.8, 1.6);
    canvas.drawCircle(sp[0], sp[1], sp[2], [sp[3][0], sp[3][1], sp[3][2], 1.0]);
    canvas.drawCircle(sp[0], sp[1], sp[2] * 0.4, [1.0, 1.0, 1.0, 1.0]);
  }

  // 5. STYLIZED TITLING ("ELECTRIC FLOW" + "CONNECT THE CIRCUITS")
  console.log('Rendering high-contrast brand typography...');
  // Title Background Ambient Glow Box
  canvas.drawRadialGlow(710, 215, 260, [0.0, 0.7, 1.0], 0.35, 2.0);
  canvas.drawRadialGlow(710, 215, 140, [0.0, 0.9, 1.0], 0.55, 1.8);

  // Render High-Tech Lettering segments for "ELECTRIC" and "FLOW"
  // Clean blocky cyber-circuit letters
  function drawLetterE(x, y, w, h, t) {
    canvas.drawLine(x, y, x, y + h, t, neonCyan);
    canvas.drawLine(x, y, x + w, y, t, neonCyan);
    canvas.drawLine(x, y + h * 0.5, x + w * 0.8, y + h * 0.5, t, neonCyan);
    canvas.drawLine(x, y + h, x + w, y + h, t, neonCyan);
  }
  function drawLetterL(x, y, w, h, t) {
    canvas.drawLine(x, y, x, y + h, t, neonCyan);
    canvas.drawLine(x, y + h, x + w, y + h, t, neonCyan);
  }
  function drawLetterC(x, y, w, h, t) {
    canvas.drawLine(x + w, y, x, y, t, neonCyan);
    canvas.drawLine(x, y, x, y + h, t, neonCyan);
    canvas.drawLine(x, y + h, x + w, y + h, t, neonCyan);
  }
  function drawLetterT(x, y, w, h, t) {
    canvas.drawLine(x, y, x + w, y, t, neonCyan);
    canvas.drawLine(x + w * 0.5, y, x + w * 0.5, y + h, t, neonCyan);
  }
  function drawLetterR(x, y, w, h, t) {
    canvas.drawLine(x, y, x, y + h, t, neonCyan);
    canvas.drawLine(x, y, x + w, y, t, neonCyan);
    canvas.drawLine(x + w, y, x + w, y + h * 0.5, t, neonCyan);
    canvas.drawLine(x, y + h * 0.5, x + w, y + h * 0.5, t, neonCyan);
    canvas.drawLine(x + w * 0.4, y + h * 0.5, x + w, y + h, t, neonCyan);
  }
  function drawLetterI(x, y, w, h, t) {
    canvas.drawLine(x + w * 0.5, y, x + w * 0.5, y + h, t, neonCyan);
    canvas.drawLine(x, y, x + w, y, t, neonCyan);
    canvas.drawLine(x, y + h, x + w, y + h, t, neonCyan);
  }
  function drawLetterF(x, y, w, h, t) {
    canvas.drawLine(x, y, x, y + h, t, neonGold);
    canvas.drawLine(x, y, x + w, y, t, neonGold);
    canvas.drawLine(x, y + h * 0.48, x + w * 0.8, y + h * 0.48, t, neonGold);
  }
  function drawLetterO(x, y, w, h, t) {
    canvas.drawLine(x, y, x + w, y, t, neonGold);
    canvas.drawLine(x + w, y, x + w, y + h, t, neonGold);
    canvas.drawLine(x + w, y + h, x, y + h, t, neonGold);
    canvas.drawLine(x, y + h, x, y, t, neonGold);
  }
  function drawLetterW(x, y, w, h, t) {
    canvas.drawLine(x, y, x + w * 0.25, y + h, t, neonGold);
    canvas.drawLine(x + w * 0.25, y + h, x + w * 0.5, y + h * 0.35, t, neonGold);
    canvas.drawLine(x + w * 0.5, y + h * 0.35, x + w * 0.75, y + h, t, neonGold);
    canvas.drawLine(x + w * 0.75, y + h, x + w, y, t, neonGold);
  }

  // Draw "ELECTRIC" (Large Neon Cyan, y = 175, h = 60)
  const eY = 170;
  const eH = 62;
  const eW = 34;
  const eThick = 7.0;

  // Backdrop glow for letters
  canvas.drawRadialGlow(710, eY + eH * 0.5, 200, [0.0, 0.8, 1.0], 0.4, 2.0);

  let lx = 500;
  drawLetterE(lx, eY, eW, eH, eThick); lx += eW + 16;
  drawLetterL(lx, eY, eW, eH, eThick); lx += eW + 16;
  drawLetterE(lx, eY, eW, eH, eThick); lx += eW + 16;
  drawLetterC(lx, eY, eW, eH, eThick); lx += eW + 16;
  drawLetterT(lx, eY, eW, eH, eThick); lx += eW + 16;
  drawLetterR(lx, eY, eW, eH, eThick); lx += eW + 16;
  drawLetterI(lx, eY, eW * 0.7, eH, eThick); lx += eW * 0.7 + 16;
  drawLetterC(lx, eY, eW, eH, eThick);

  // Draw "FLOW" (Massive Golden Sunburst, y = 250, h = 78)
  const fY = 250;
  const fH = 78;
  const fW = 54;
  const fThick = 9.5;

  canvas.drawRadialGlow(710, fY + fH * 0.5, 180, [1.0, 0.8, 0.2], 0.55, 1.8);

  let fx = 560;
  drawLetterF(fx, fY, fW, fH, fThick); fx += fW + 24;
  // Golden L
  canvas.drawLine(fx, fY, fx, fY + fH, fThick, neonGold);
  canvas.drawLine(fx, fY + fH, fx + fW, fY + fH, fThick, neonGold);
  fx += fW + 24;
  drawLetterO(fx, fY, fW, fH, fThick); fx += fW + 24;
  drawLetterW(fx, fY, fW, fH, fThick);

  // Subtitle Pill Badge: "CONNECT THE CIRCUITS"
  const tagX0 = 530;
  const tagX1 = 890;
  const tagY = 360;
  const tagR = 14;

  canvas.drawLine(tagX0 + tagR, tagY, tagX1 - tagR, tagY, tagR * 2, [0.03, 0.12, 0.24, 0.95]);
  canvas.drawCircle(tagX0 + tagR, tagY, tagR, [0.03, 0.12, 0.24, 0.95]);
  canvas.drawCircle(tagX1 - tagR, tagY, tagR, [0.03, 0.12, 0.24, 0.95]);

  canvas.drawLine(tagX0 + tagR, tagY - tagR, tagX1 - tagR, tagY - tagR, 2.0, neonCyan);
  canvas.drawLine(tagX0 + tagR, tagY + tagR, tagX1 - tagR, tagY + tagR, 2.0, neonCyan);

  // Subtitle accent nodes
  canvas.drawCircle(tagX0 + tagR, tagY, 4.5, neonGold);
  canvas.drawCircle(tagX1 - tagR, tagY, 4.5, neonGold);
  canvas.drawCircle(710, tagY, 4.0, [0.0, 1.0, 0.8, 1.0]);

  // Modern Circuit Border Frame around entire 1024x500 banner
  const borderMargin = 12;
  canvas.drawLine(borderMargin, borderMargin, W - borderMargin, borderMargin, 2.0, [0.0, 0.7, 1.0, 0.55]);
  canvas.drawLine(W - borderMargin, borderMargin, W - borderMargin, H - borderMargin, 2.0, [0.0, 0.7, 1.0, 0.55]);
  canvas.drawLine(W - borderMargin, H - borderMargin, borderMargin, H - borderMargin, 2.0, [0.0, 0.7, 1.0, 0.55]);
  canvas.drawLine(borderMargin, H - borderMargin, borderMargin, borderMargin, 2.0, [0.0, 0.7, 1.0, 0.55]);

  // Corner Chamfers
  const chamfer = 24;
  canvas.drawCircle(borderMargin + chamfer, borderMargin + chamfer, 3.5, neonGold);
  canvas.drawCircle(W - borderMargin - chamfer, borderMargin + chamfer, 3.5, neonGold);
  canvas.drawCircle(borderMargin + chamfer, H - borderMargin - chamfer, 3.5, neonGold);
  canvas.drawCircle(W - borderMargin - chamfer, H - borderMargin - chamfer, 3.5, neonGold);

  console.log('Encoding 1024x500 PNG buffer...');
  return encodePNG(W, H, canvas.buf);
}

// Generate the Google Play Feature Graphic SVG
function generateFeatureGraphicSVG() {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 500" width="1024" height="500">
  <defs>
    <!-- Background Radial Gradient -->
    <radialGradient id="bgGrad" cx="30%" cy="48%" r="75%">
      <stop offset="0%" stop-color="#0a2a56"/>
      <stop offset="45%" stop-color="#051630"/>
      <stop offset="100%" stop-color="#020914"/>
    </radialGradient>

    <!-- Neon Glow Filter -->
    <filter id="neonGlow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="8" result="blur"/>
      <feMerge>
        <feMergeNode in="blur"/>
        <feMergeNode in="blur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>

    <!-- Intense Bolt Glow -->
    <filter id="boltGlow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="15" result="b1"/>
      <feGaussianBlur in="SourceGraphic" stdDeviation="6" result="b2"/>
      <feMerge>
        <feMergeNode in="b1"/>
        <feMergeNode in="b2"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>

    <!-- Bolt Gradient -->
    <linearGradient id="boltGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="35%" stop-color="#fff59d"/>
      <stop offset="100%" stop-color="#ff9800"/>
    </linearGradient>

    <!-- Brass Gradient -->
    <linearGradient id="brassGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#8d6e18"/>
      <stop offset="35%" stop-color="#ffd54f"/>
      <stop offset="70%" stop-color="#fff59d"/>
      <stop offset="100%" stop-color="#6d5410"/>
    </linearGradient>

    <!-- Core Bloom -->
    <radialGradient id="bulbBloom" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.95"/>
      <stop offset="25%" stop-color="#ffd700" stop-opacity="0.75"/>
      <stop offset="60%" stop-color="#00e5ff" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#00e5ff" stop-opacity="0.0"/>
    </radialGradient>
  </defs>

  <!-- Background -->
  <rect width="1024" height="500" fill="url(#bgGrad)"/>

  <!-- Cyber Grid -->
  <g stroke="#00b0ff" stroke-width="1.2" opacity="0.12">
    <line x1="64" y1="0" x2="64" y2="500"/><line x1="128" y1="0" x2="128" y2="500"/>
    <line x1="192" y1="0" x2="192" y2="500"/><line x1="256" y1="0" x2="256" y2="500"/>
    <line x1="320" y1="0" x2="320" y2="500"/><line x1="384" y1="0" x2="384" y2="500"/>
    <line x1="448" y1="0" x2="448" y2="500"/><line x1="512" y1="0" x2="512" y2="500"/>
    <line x1="576" y1="0" x2="576" y2="500"/><line x1="640" y1="0" x2="640" y2="500"/>
    <line x1="704" y1="0" x2="704" y2="500"/><line x1="768" y1="0" x2="768" y2="500"/>
    <line x1="832" y1="0" x2="832" y2="500"/><line x1="896" y1="0" x2="896" y2="500"/>
    <line x1="960" y1="0" x2="960" y2="500"/>
    <line x1="0" y1="64" x2="1024" y2="64"/><line x1="0" y1="128" x2="1024" y2="128"/>
    <line x1="0" y1="192" x2="1024" y2="192"/><line x1="0" y1="256" x2="1024" y2="256"/>
    <line x1="0" y1="320" x2="1024" y2="320"/><line x1="0" y1="384" x2="1024" y2="384"/>
    <line x1="0" y1="448" x2="1024" y2="448"/>
  </g>

  <!-- Circuit Traces across Banner -->
  <g stroke="#00e5ff" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" filter="url(#neonGlow)">
    <polyline points="20,160 110,160 150,200" fill="none"/>
    <polyline points="20,300 110,300 150,260" fill="none"/>
    <line x1="240" y1="20" x2="240" y2="95"/>
    <line x1="240" y1="480" x2="240" y2="395"/>
    <polyline points="330,230 390,230 430,190 530,190" fill="none"/>
    <polyline points="330,260 390,260 430,300 530,300" fill="none"/>
    <polyline points="530,140 780,140 820,180 990,180" fill="none"/>
    <polyline points="530,350 780,350 820,310 990,310" fill="none"/>
    <polyline points="990,245 910,245 880,215" fill="none"/>
  </g>

  <!-- Golden Terminals -->
  <g filter="url(#neonGlow)">
    <circle cx="20" cy="160" r="6.5" fill="#ffd700"/>
    <circle cx="20" cy="300" r="6.5" fill="#ffd700"/>
    <circle cx="240" cy="20" r="6.5" fill="#ffd700"/>
    <circle cx="240" cy="480" r="6.5" fill="#ffd700"/>
    <circle cx="430" cy="190" r="6.5" fill="#ffd700"/>
    <circle cx="430" cy="300" r="6.5" fill="#ffd700"/>
    <circle cx="530" cy="140" r="6.5" fill="#ffd700"/>
    <circle cx="530" cy="350" r="6.5" fill="#ffd700"/>
    <circle cx="990" cy="180" r="6.5" fill="#ffd700"/>
    <circle cx="990" cy="310" r="6.5" fill="#ffd700"/>
    <circle cx="990" cy="245" r="6.5" fill="#ffd700"/>
  </g>

  <!-- Bulb Ambient Bloom -->
  <circle cx="240" cy="240" r="220" fill="url(#bulbBloom)"/>

  <!-- Bulb Glass Envelope -->
  <path d="M 240,135
           C 174,135 135,182 135,240
           C 135,284 158,310 186,344
           L 186,360
           L 294,360
           L 294,344
           C 322,310 345,284 345,240
           C 345,182 306,135 240,135 Z"
        fill="#041a38" fill-opacity="0.45"
        stroke="#40c4ff" stroke-width="5" filter="url(#neonGlow)"/>

  <!-- Specular Reflection -->
  <path d="M 165,182 A 90 90 0 0 1 225,146"
        fill="none" stroke="#ffffff" stroke-width="7" stroke-linecap="round" opacity="0.85"/>

  <!-- Brass Screw Base -->
  <rect x="186" y="360" width="108" height="15" rx="7.5" fill="url(#brassGrad)"/>
  <rect x="190" y="375" width="100" height="14" rx="7" fill="url(#brassGrad)"/>
  <rect x="196" y="389" width="88" height="14" rx="7" fill="url(#brassGrad)"/>
  <ellipse cx="240" cy="408" rx="20" ry="7" fill="#1c1c1c"/>
  <ellipse cx="240" cy="410" rx="11" ry="4" fill="#cfd8dc" filter="url(#neonGlow)"/>

  <!-- High-Voltage Lightning Bolt Core -->
  <polygon points="254,160 185,246 233,250 190,334 294,236 244,232 276,160"
           fill="url(#boltGrad)" stroke="#ffffff" stroke-width="3" filter="url(#boltGlow)"/>

  <!-- Sparks -->
  <g fill="#ffffff" filter="url(#neonGlow)">
    <circle cx="150" cy="200" r="5"/>
    <circle cx="330" cy="205" r="4.5"/>
    <circle cx="160" cy="300" r="4"/>
    <circle cx="320" cy="295" r="5.5"/>
    <circle cx="240" cy="100" r="6"/>
  </g>

  <!-- Typography: ELECTRIC FLOW -->
  <text x="710" y="225" text-anchor="middle" font-family="system-ui, -apple-system, sans-serif" font-weight="900" font-size="64" letter-spacing="8" fill="#ffffff" stroke="#00e5ff" stroke-width="3" filter="url(#neonGlow)">ELECTRIC</text>
  <text x="710" y="315" text-anchor="middle" font-family="system-ui, -apple-system, sans-serif" font-weight="900" font-size="82" letter-spacing="12" fill="#ffd700" stroke="#ff9800" stroke-width="3" filter="url(#neonGlow)">FLOW</text>

  <!-- Subtitle Tag -->
  <rect x="540" y="348" width="340" height="28" rx="14" fill="#041429" stroke="#00e5ff" stroke-width="2" filter="url(#neonGlow)"/>
  <text x="710" y="367" text-anchor="middle" font-family="system-ui, -apple-system, sans-serif" font-weight="700" font-size="14" letter-spacing="4" fill="#80d8ff">CONNECT THE CIRCUITS</text>
  <circle cx="554" cy="362" r="4" fill="#ffd700"/>
  <circle cx="866" cy="362" r="4" fill="#ffd700"/>

  <!-- Outer Frame -->
  <rect x="12" y="12" width="1000" height="476" rx="8" fill="none" stroke="#00b0ff" stroke-width="2" opacity="0.45"/>
  <circle cx="36" cy="36" r="4" fill="#ffd700"/>
  <circle cx="988" cy="36" r="4" fill="#ffd700"/>
  <circle cx="36" cy="464" r="4" fill="#ffd700"/>
  <circle cx="988" cy="464" r="4" fill="#ffd700"/>
</svg>`;
}

// Generate files
console.log('Generating Google Play 1024x500 Feature Graphic...');
const bannerPNG = generateFeatureGraphic();
fs.writeFileSync('feature_graphic_1024x500.png', bannerPNG);
fs.writeFileSync('assets/generated/feature-graphic.png', bannerPNG);
console.log('✓ Successfully saved feature_graphic_1024x500.png (' + bannerPNG.length + ' bytes)');

const bannerSVG = generateFeatureGraphicSVG();
fs.writeFileSync('feature_graphic_1024x500.svg', bannerSVG);
fs.writeFileSync('assets/generated/feature-graphic.svg', bannerSVG);
console.log('✓ Successfully saved feature_graphic_1024x500.svg');

console.log('>>> 1024x500 FEATURE GRAPHIC GENERATION COMPLETE! <<<');
