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

// Pure Node.js PNG encoder
function encodePNG(width, height, rgbaBuffer) {
  const rowLen = width * 4;
  const filtered = Buffer.alloc(height * (rowLen + 1));
  for (let y = 0; y < height; y++) {
    filtered[y * (rowLen + 1)] = 0; // Filter: None
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
  ihdrData[9] = 6;
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

// High Precision 2D Antialiased Canvas
class IconCanvas {
  constructor(size) {
    this.size = size;
    this.buf = Buffer.alloc(size * size * 4, 0);
  }

  setPixel(x, y, r, g, b, a = 1.0) {
    x = Math.round(x);
    y = Math.round(y);
    if (x < 0 || x >= this.size || y < 0 || y >= this.size || a <= 0.001) return;
    const idx = (y * this.size + x) * 4;
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
    const x1 = Math.min(this.size - 1, Math.ceil(cx + r));
    const y0 = Math.max(0, Math.floor(cy - r));
    const y1 = Math.min(this.size - 1, Math.ceil(cy + r));
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
    const x1 = Math.min(this.size - 1, Math.ceil(cx + radius + feather));
    const y0 = Math.max(0, Math.floor(cy - radius - feather));
    const y1 = Math.min(this.size - 1, Math.ceil(cy + radius + feather));

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
    const maxX = Math.min(this.size - 1, Math.ceil(Math.max(x0, x1) + hw + 1));
    const minY = Math.max(0, Math.floor(Math.min(y0, y1) - hw - 1));
    const maxY = Math.min(this.size - 1, Math.ceil(Math.max(y0, y1) + hw + 1));

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
    let minX = this.size, maxX = 0, minY = this.size, maxY = 0;
    for (const p of points) {
      if (p[0] < minX) minX = p[0];
      if (p[0] > maxX) maxX = p[0];
      if (p[1] < minY) minY = p[1];
      if (p[1] > maxY) maxY = p[1];
    }
    minX = Math.max(0, Math.floor(minX - 1));
    maxX = Math.min(this.size - 1, Math.ceil(maxX + 1));
    minY = Math.max(0, Math.floor(minY - 1));
    maxY = Math.min(this.size - 1, Math.ceil(maxY + 1));

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

// Render New Electric Flow Icon with Maximum Polish
function renderElectricFlowIcon(size, isForegroundOnly = false) {
  const canvas = new IconCanvas(size);
  const s = size / 512.0;
  const cx = size * 0.5;
  const cy = 230 * s;

  // 1. BACKGROUND (Skipped for transparent adaptive foreground)
  if (!isForegroundOnly) {
    const maxR = size * 0.72;
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const dx = x - cx;
        const dy = y - (size * 0.48);
        const d = Math.sqrt(dx * dx + dy * dy) / maxR;
        const t = Math.min(1.0, d);

        // Vibrant cyber sapphire center (#0a2d5e) fading to deep dark midnight navy (#020813)
        const r = (10 * (1 - t) + 2 * t) / 255.0;
        const g = (45 * (1 - t) + 8 * t) / 255.0;
        const b = (94 * (1 - t) + 19 * t) / 255.0;
        canvas.setPixel(x, y, r, g, b, 1.0);
      }
    }

    // Modern Circuit Grid Lines
    const step = 32 * s;
    for (let p = step; p < size; p += step) {
      canvas.drawLine(p, 0, p, size, 1.0 * s, [0.0, 0.55, 0.9, 0.10]);
      canvas.drawLine(0, p, size, p, 1.0 * s, [0.0, 0.55, 0.9, 0.10]);
    }

    // Outer Icon Beveled Frame & Corner Accent
    const m = 14 * s;
    canvas.drawLine(m, m, size - m, m, 2.0 * s, [0.0, 0.75, 1.0, 0.45]);
    canvas.drawLine(size - m, m, size - m, size - m, 2.0 * s, [0.0, 0.75, 1.0, 0.45]);
    canvas.drawLine(size - m, size - m, m, size - m, 2.0 * s, [0.0, 0.75, 1.0, 0.45]);
    canvas.drawLine(m, size - m, m, m, 2.0 * s, [0.0, 0.75, 1.0, 0.45]);

    // Outer Ambient Glow
    canvas.drawRadialGlow(cx, cy, 240 * s, [0.0, 0.8, 1.0], 0.28, 2.2);
  }

  // 2. GLOWING CIRCUIT TRACKS
  const neonCyan = [0.0, 0.95, 1.0, 0.95];
  const neonGold = [1.0, 0.85, 0.15, 1.0];

  const traces = [
    // Top feeder
    [[cx, 35 * s], [cx, 110 * s]],
    // Bottom feeder
    [[cx, 475 * s], [cx, 400 * s]],
    // Left routes
    [[35 * s, 145 * s], [120 * s, 145 * s], [165 * s, 190 * s]],
    [[35 * s, 250 * s], [140 * s, 250 * s]],
    [[35 * s, 355 * s], [120 * s, 355 * s], [165 * s, 310 * s]],
    // Right routes
    [[477 * s, 145 * s], [392 * s, 145 * s], [347 * s, 190 * s]],
    [[477 * s, 250 * s], [372 * s, 250 * s]],
    [[477 * s, 355 * s], [392 * s, 355 * s], [347 * s, 310 * s]]
  ];

  for (const poly of traces) {
    for (let i = 0; i < poly.length - 1; i++) {
      const p0 = poly[i];
      const p1 = poly[i + 1];
      // Cyan bloom underlay
      canvas.drawLine(p0[0], p0[1], p1[0], p1[1], 12.0 * s, [0.0, 0.7, 1.0, 0.35]);
      // Core neon wire
      canvas.drawLine(p0[0], p0[1], p1[0], p1[1], 4.5 * s, neonCyan);
      // Bright white central energy core
      canvas.drawLine(p0[0], p0[1], p1[0], p1[1], 1.5 * s, [0.85, 1.0, 1.0, 0.95]);
    }
  }

  // Golden Terminal Nodes
  const terminals = [
    [cx, 35 * s], [cx, 475 * s],
    [35 * s, 145 * s], [35 * s, 250 * s], [35 * s, 355 * s],
    [477 * s, 145 * s], [477 * s, 250 * s], [477 * s, 355 * s]
  ];

  for (const pt of terminals) {
    canvas.drawRadialGlow(pt[0], pt[1], 18 * s, [1.0, 0.8, 0.1], 0.75, 1.8);
    canvas.drawCircle(pt[0], pt[1], 7.5 * s, [0.0, 0.22, 0.42, 0.9]);
    canvas.drawCircle(pt[0], pt[1], 5.5 * s, neonGold);
    canvas.drawCircle(pt[0], pt[1], 2.5 * s, [1.0, 1.0, 0.9, 1.0]);
  }

  // 3. GLOWING ENERGY BLOOM
  canvas.drawRadialGlow(cx, cy, 210 * s, [0.0, 0.85, 1.0], 0.40, 1.7);
  canvas.drawRadialGlow(cx, cy, 130 * s, [1.0, 0.85, 0.2], 0.70, 1.8);
  canvas.drawRadialGlow(cx, cy, 60 * s, [1.0, 1.0, 0.8], 0.98, 2.0);

  // 4. BULB GLASS ENVELOPE (Smooth curve)
  const bulbPoints = [];
  const segments = 48;
  for (let i = 0; i <= segments; i++) {
    const angle = Math.PI * 0.18 + (i / segments) * (Math.PI * 1.64);
    const r = 104 * s;
    const bx = cx + Math.cos(angle) * r;
    const by = cy - Math.sin(angle) * r;
    bulbPoints.push([bx, by]);
  }
  bulbPoints.push([cx + 52 * s, cy + 104 * s]);
  bulbPoints.push([cx + 52 * s, cy + 120 * s]);
  bulbPoints.push([cx - 52 * s, cy + 120 * s]);
  bulbPoints.push([cx - 52 * s, cy + 104 * s]);

  // Dark tinted glass body
  canvas.drawPolygon(bulbPoints, [0.02, 0.14, 0.28, 0.55]);

  // Glass Neon Outline
  for (let i = 0; i < bulbPoints.length - 1; i++) {
    canvas.drawLine(bulbPoints[i][0], bulbPoints[i][1], bulbPoints[i + 1][0], bulbPoints[i + 1][1], 5.5 * s, [0.35, 0.9, 1.0, 0.9]);
    canvas.drawLine(bulbPoints[i][0], bulbPoints[i][1], bulbPoints[i + 1][0], bulbPoints[i + 1][1], 1.8 * s, [0.9, 1.0, 1.0, 1.0]);
  }

  // Specular Reflection Curved Highlight
  for (let a = 2.1; a <= 2.9; a += 0.03) {
    const hx = cx + Math.cos(a) * 86 * s;
    const hy = cy - Math.sin(a) * 86 * s;
    canvas.drawCircle(hx, hy, 4.8 * s, [1.0, 1.0, 1.0, 0.8]);
  }

  // 5. BRASS SCREW BASE (Polished Metallic Sheen)
  function drawBaseSegment(yOffset, w, h) {
    const x0 = (cx - w * 0.5 * s);
    const x1 = (cx + w * 0.5 * s);
    const y0 = cy + yOffset * s;
    const y1 = y0 + h * s;
    for (let py = y0; py <= y1; py++) {
      for (let px = x0; px <= x1; px++) {
        const u = (px - x0) / ((x1 - x0) || 1);
        let col;
        if (u < 0.25) col = [0.58, 0.40, 0.09, 1.0];
        else if (u < 0.65) col = [1.0, 0.95, 0.65, 1.0];
        else col = [0.90, 0.72, 0.18, 1.0];
        canvas.setPixel(px, py, col[0], col[1], col[2], 1.0);
      }
    }
    canvas.drawLine(x0, y0, x1, y0, 1.5 * s, [1.0, 0.95, 0.7, 1.0]);
    canvas.drawLine(x0, y1, x1, y1, 1.5 * s, [0.5, 0.35, 0.08, 1.0]);
  }

  drawBaseSegment(120, 108, 14);
  drawBaseSegment(134, 100, 14);
  drawBaseSegment(148, 88, 14);

  // Ceramic base & Silver contact
  canvas.drawCircle(cx, cy + 168 * s, 18 * s, [0.12, 0.12, 0.14, 1.0]);
  canvas.drawCircle(cx, cy + 168 * s, 9 * s, [0.85, 0.92, 0.98, 1.0]);

  // 6. HIGH-VOLTAGE LIGHTNING BOLT CORE (Center Highlight)
  const boltOuter = [
    [cx + 14 * s, cy - 80 * s],
    [cx - 55 * s, cy + 6 * s],
    [cx - 7 * s, cy + 10 * s],
    [cx - 50 * s, cy + 94 * s],
    [cx + 54 * s, cy - 4 * s],
    [cx + 4 * s, cy - 8 * s],
    [cx + 36 * s, cy - 80 * s]
  ];

  canvas.drawRadialGlow(cx, cy + 8 * s, 85 * s, [1.0, 0.85, 0.2], 0.95, 1.8);
  canvas.drawRadialGlow(cx, cy + 8 * s, 40 * s, [1.0, 1.0, 1.0], 1.0, 2.0);
  canvas.drawPolygon(boltOuter, [1.0, 0.84, 0.15, 1.0]);

  const boltInner = [
    [cx + 13 * s, cy - 72 * s],
    [cx - 42 * s, cy + 4 * s],
    [cx - 5 * s, cy + 8 * s],
    [cx - 36 * s, cy + 82 * s],
    [cx + 44 * s, cy - 2 * s],
    [cx + 6 * s, cy - 6 * s],
    [cx + 31 * s, cy - 72 * s]
  ];
  canvas.drawPolygon(boltInner, [1.0, 1.0, 0.92, 1.0]);

  for (let i = 0; i < boltOuter.length; i++) {
    const p0 = boltOuter[i];
    const p1 = boltOuter[(i + 1) % boltOuter.length];
    canvas.drawLine(p0[0], p0[1], p1[0], p1[1], 3.5 * s, [1.0, 0.95, 0.65, 1.0]);
  }

  // 7. SPARKS & ELECTRICAL EMISSIONS
  const sparks = [
    [cx - 85 * s, cy - 35 * s, 5.0 * s, [1.0, 1.0, 1.0]],
    [cx + 85 * s, cy - 30 * s, 5.0 * s, [1.0, 1.0, 1.0]],
    [cx - 75 * s, cy + 55 * s, 4.5 * s, [0.0, 0.9, 1.0]],
    [cx + 75 * s, cy + 50 * s, 5.5 * s, [1.0, 0.9, 0.3]],
    [cx, cy - 130 * s, 6.0 * s, [1.0, 0.95, 0.4]],
    [cx - 120 * s, cy + 10 * s, 4.0 * s, [0.0, 1.0, 0.8]],
    [cx + 120 * s, cy + 8 * s, 4.0 * s, [0.0, 1.0, 0.8]]
  ];

  for (const sp of sparks) {
    canvas.drawRadialGlow(sp[0], sp[1], sp[2] * 4, sp[3], 0.8, 1.6);
    canvas.drawCircle(sp[0], sp[1], sp[2], [sp[3][0], sp[3][1], sp[3][2], 1.0]);
    canvas.drawCircle(sp[0], sp[1], sp[2] * 0.45, [1.0, 1.0, 1.0, 1.0]);
  }

  // 8. LOWER BRAND BADGE PLATE (Modern Capsule)
  const plateX0 = 136 * s;
  const plateX1 = 376 * s;
  const plateY = 432 * s;
  const plateR = 14 * s;

  canvas.drawLine(plateX0 + plateR, plateY, plateX1 - plateR, plateY, plateR * 2, [0.02, 0.10, 0.22, 0.95]);
  canvas.drawCircle(plateX0 + plateR, plateY, plateR, [0.02, 0.10, 0.22, 0.95]);
  canvas.drawCircle(plateX1 - plateR, plateY, plateR, [0.02, 0.10, 0.22, 0.95]);

  canvas.drawLine(plateX0 + plateR, plateY - plateR, plateX1 - plateR, plateY - plateR, 2.5 * s, neonCyan);
  canvas.drawLine(plateX0 + plateR, plateY + plateR, plateX1 - plateR, plateY + plateR, 2.5 * s, neonCyan);

  // Status Indicator Nodes
  canvas.drawCircle(cx, plateY, 5.5 * s, [0.0, 1.0, 0.8, 1.0]);
  canvas.drawCircle(cx, plateY, 2.5 * s, [1.0, 1.0, 1.0, 1.0]);
  canvas.drawCircle(cx - 46 * s, plateY, 3.5 * s, neonGold);
  canvas.drawCircle(cx + 46 * s, plateY, 3.5 * s, neonGold);

  return encodePNG(size, size, canvas.buf);
}

// Generate Vector SVG
function generateVectorSVG() {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <radialGradient id="bgGrad" cx="50%" cy="48%" r="70%">
      <stop offset="0%" stop-color="#0a2d5e"/>
      <stop offset="60%" stop-color="#041530"/>
      <stop offset="100%" stop-color="#020813"/>
    </radialGradient>
    <filter id="neonGlow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="8" result="blur"/>
      <feMerge>
        <feMergeNode in="blur"/>
        <feMergeNode in="blur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
    <filter id="boltGlow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="14" result="b1"/>
      <feGaussianBlur in="SourceGraphic" stdDeviation="6" result="b2"/>
      <feMerge>
        <feMergeNode in="b1"/>
        <feMergeNode in="b2"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
    <linearGradient id="boltGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="35%" stop-color="#fff59d"/>
      <stop offset="100%" stop-color="#ff9800"/>
    </linearGradient>
    <linearGradient id="brassGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#8d6e18"/>
      <stop offset="35%" stop-color="#ffd54f"/>
      <stop offset="70%" stop-color="#fff59d"/>
      <stop offset="100%" stop-color="#6d5410"/>
    </linearGradient>
    <radialGradient id="bulbBloom" cx="50%" cy="46%" r="50%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.95"/>
      <stop offset="25%" stop-color="#ffd700" stop-opacity="0.75"/>
      <stop offset="60%" stop-color="#00e5ff" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#00e5ff" stop-opacity="0.0"/>
    </radialGradient>
  </defs>

  <rect width="512" height="512" rx="100" fill="url(#bgGrad)"/>
  <rect x="14" y="14" width="484" height="484" rx="86" fill="none" stroke="#00b0ff" stroke-width="2" opacity="0.45"/>

  <!-- Grid -->
  <g stroke="#00b0ff" stroke-width="1.2" opacity="0.10">
    <line x1="64" y1="0" x2="64" y2="512"/><line x1="128" y1="0" x2="128" y2="512"/>
    <line x1="192" y1="0" x2="192" y2="512"/><line x1="256" y1="0" x2="256" y2="512"/>
    <line x1="320" y1="0" x2="320" y2="512"/><line x1="384" y1="0" x2="384" y2="512"/>
    <line x1="448" y1="0" x2="448" y2="512"/>
    <line x1="0" y1="64" x2="512" y2="64"/><line x1="0" y1="128" x2="512" y2="128"/>
    <line x1="0" y1="192" x2="512" y2="192"/><line x1="0" y1="256" x2="512" y2="256"/>
    <line x1="0" y1="320" x2="512" y2="320"/><line x1="0" y1="384" x2="512" y2="384"/>
    <line x1="0" y1="448" x2="512" y2="448"/>
  </g>

  <!-- Traces -->
  <g stroke="#00e5ff" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" filter="url(#neonGlow)">
    <line x1="256" y1="35" x2="256" y2="110"/>
    <line x1="256" y1="475" x2="256" y2="400"/>
    <polyline points="35,145 120,145 165,190" fill="none"/>
    <polyline points="35,250 140,250" fill="none"/>
    <polyline points="35,355 120,355 165,310" fill="none"/>
    <polyline points="477,145 392,145 347,190" fill="none"/>
    <polyline points="477,250 372,250" fill="none"/>
    <polyline points="477,355 392,355 347,310" fill="none"/>
  </g>

  <!-- Terminals -->
  <g filter="url(#neonGlow)">
    <circle cx="256" cy="35" r="6.5" fill="#ffd700"/>
    <circle cx="256" cy="475" r="6.5" fill="#ffd700"/>
    <circle cx="35" cy="145" r="6.5" fill="#ffd700"/>
    <circle cx="35" cy="250" r="6.5" fill="#ffd700"/>
    <circle cx="35" cy="355" r="6.5" fill="#ffd700"/>
    <circle cx="477" cy="145" r="6.5" fill="#ffd700"/>
    <circle cx="477" cy="250" r="6.5" fill="#ffd700"/>
    <circle cx="477" cy="355" r="6.5" fill="#ffd700"/>
  </g>

  <!-- Bulb Ambient Bloom -->
  <circle cx="256" cy="230" r="210" fill="url(#bulbBloom)"/>

  <!-- Bulb Glass Envelope -->
  <path d="M 256,126
           C 192,126 152,172 152,230
           C 152,274 174,300 204,334
           L 204,350
           L 308,350
           L 308,334
           C 338,300 360,274 360,230
           C 360,172 320,126 256,126 Z"
        fill="#041a38" fill-opacity="0.45"
        stroke="#40c4ff" stroke-width="5" filter="url(#neonGlow)"/>

  <!-- Specular Reflection -->
  <path d="M 178,172 A 86 86 0 0 1 238,136"
        fill="none" stroke="#ffffff" stroke-width="7" stroke-linecap="round" opacity="0.85"/>

  <!-- Brass Screw Base -->
  <rect x="202" y="350" width="108" height="14" rx="7" fill="url(#brassGrad)"/>
  <rect x="206" y="364" width="100" height="14" rx="7" fill="url(#brassGrad)"/>
  <rect x="212" y="378" width="88" height="14" rx="7" fill="url(#brassGrad)"/>
  <ellipse cx="256" cy="398" rx="18" ry="6" fill="#1c1c1c"/>
  <ellipse cx="256" cy="400" rx="10" ry="4" fill="#cfd8dc" filter="url(#neonGlow)"/>

  <!-- Lightning Bolt -->
  <polygon points="270,150 201,236 249,240 206,324 310,226 260,222 292,150"
           fill="url(#boltGrad)" stroke="#ffffff" stroke-width="3" filter="url(#boltGlow)"/>

  <!-- Sparks -->
  <g fill="#ffffff" filter="url(#neonGlow)">
    <circle cx="171" cy="195" r="5"/>
    <circle cx="341" cy="200" r="4.5"/>
    <circle cx="181" cy="285" r="4"/>
    <circle cx="331" cy="280" r="5.5"/>
    <circle cx="256" cy="100" r="6"/>
  </g>

  <!-- Lower Tech Plate -->
  <rect x="136" y="418" width="240" height="28" rx="14" fill="#041429" stroke="#00e5ff" stroke-width="2" filter="url(#neonGlow)"/>
  <circle cx="256" cy="432" r="5.5" fill="#00ffcc" filter="url(#neonGlow)"/>
  <circle cx="210" cy="432" r="3.5" fill="#ffd700"/>
  <circle cx="302" cy="432" r="3.5" fill="#ffd700"/>
</svg>`;
}

// Generate all target icon files
console.log('Rendering new Electric Flow master icons...');

const icon512 = renderElectricFlowIcon(512, false);
fs.writeFileSync('assets/generated/app-icon.png', icon512);
fs.writeFileSync('assets/generated/app-icon-safe.png', icon512);
console.log('✓ Saved assets/generated/app-icon.png (512x512)');

const icon1024 = renderElectricFlowIcon(1024, false);
fs.writeFileSync('assets/generated/app-icon-1024.png', icon1024);
console.log('✓ Saved assets/generated/app-icon-1024.png (1024x1024)');

const fg432 = renderElectricFlowIcon(432, true);
fs.writeFileSync('assets/generated/app-icon-foreground.png', fg432);
console.log('✓ Saved assets/generated/app-icon-foreground.png (432x432)');

const svg = generateVectorSVG();
fs.writeFileSync('assets/generated/app-icon.svg', svg);
fs.writeFileSync('assets/generated/app-icon-background.svg', svg);
fs.writeFileSync('icon.svg', svg);
console.log('✓ Saved assets/generated/app-icon.svg & icon.svg');

// Godot's Android exporter automatically generates mipmap icon.webp from
// assets/generated/app-icon-safe.png configured in export_presets.cfg.
// We intentionally do not place icon.png in android/build/res/mipmap to prevent AAPT2 duplicate resource errors.
console.log('>>> NEW MASTER ICON GENERATION COMPLETE! <<<');
