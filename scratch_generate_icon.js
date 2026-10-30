const fs = require('fs');
const zlib = require('zlib');
const path = require('path');

// CRC32 implementation
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
  ihdrData[8] = 8; // bit depth
  ihdrData[9] = 6; // RGBA
  ihdrData[10] = 0; // compression
  ihdrData[11] = 0; // filter
  ihdrData[12] = 0; // interlace
  
  const ihdr = makeChunk('IHDR', ihdrData);
  const idat = makeChunk('IDAT', idatData);
  const iend = makeChunk('IEND', Buffer.alloc(0));
  
  return Buffer.concat([header, ihdr, idat, iend]);
}

// Pixel buffer class
class PixelCanvas {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.buf = Buffer.alloc(w * h * 4, 0);
  }

  setPixel(x, y, r, g, b, a = 1.0) {
    if (x < 0 || x >= this.w || y < 0 || y >= this.h || a <= 0) return;
    const idx = (y * this.w + x) * 4;
    const sa = Math.min(1.0, a);
    const da = this.buf[idx + 3] / 255.0;
    const outA = sa + da * (1.0 - sa);
    if (outA <= 0.001) return;

    const sr = r * sa;
    const sg = g * sa;
    const sb = b * sa;
    const dr = (this.buf[idx] / 255.0) * da * (1.0 - sa);
    const dg = (this.buf[idx + 1] / 255.0) * da * (1.0 - sa);
    const db = (this.buf[idx + 2] / 255.0) * da * (1.0 - sa);

    this.buf[idx] = Math.min(255, Math.round(((sr + dr) / outA) * 255));
    this.buf[idx + 1] = Math.min(255, Math.round(((sg + dg) / outA) * 255));
    this.buf[idx + 2] = Math.min(255, Math.round(((sb + db) / outA) * 255));
    this.buf[idx + 3] = Math.min(255, Math.round(outA * 255));
  }

  // Draw smooth distance field rounded rectangle
  drawRoundedRect(x0, y0, x1, y1, radius, colorFn) {
    for (let y = Math.floor(y0); y <= Math.ceil(y1); y++) {
      for (let x = Math.floor(x0); x <= Math.ceil(x1); x++) {
        // Distance to rounded box
        const qx = Math.abs(x - (x0 + x1) * 0.5) - ((x1 - x0) * 0.5 - radius);
        const qy = Math.abs(y - (y0 + y1) * 0.5) - ((y1 - y0) * 0.5 - radius);
        const mx = Math.max(qx, 0.0);
        const my = Math.max(qy, 0.0);
        const dist = Math.sqrt(mx * mx + my * my) + Math.min(Math.max(qx, qy), 0.0) - radius;
        
        if (dist <= 1.0) {
          const alpha = Math.max(0.0, Math.min(1.0, 0.5 - dist));
          if (alpha > 0) {
            const col = colorFn(x, y, (x - x0) / (x1 - x0), (y - y0) / (y1 - y0));
            this.setPixel(x, y, col[0], col[1], col[2], col[3] * alpha);
          }
        }
      }
    }
  }

  // Draw line segment with antialiased thickness and glow
  drawLine(ax, ay, bx, by, thick, r, g, b, a, glowRadius = 0) {
    const minX = Math.max(0, Math.floor(Math.min(ax, bx) - thick - glowRadius - 2));
    const maxX = Math.min(this.w - 1, Math.ceil(Math.max(ax, bx) + thick + glowRadius + 2));
    const minY = Math.max(0, Math.floor(Math.min(ay, by) - thick - glowRadius - 2));
    const maxY = Math.min(this.h - 1, Math.ceil(Math.max(ay, by) + thick + glowRadius + 2));

    const dx = bx - ax;
    const dy = by - ay;
    const lenSq = dx * dx + dy * dy;

    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        let t = lenSq === 0 ? 0 : ((x - ax) * dx + (y - ay) * dy) / lenSq;
        t = Math.max(0, Math.min(1, t));
        const px = ax + t * dx;
        const py = ay + t * dy;
        const dist = Math.hypot(x - px, y - py);

        // Core line
        if (dist <= thick * 0.5 + 0.75) {
          const alpha = Math.max(0.0, Math.min(1.0, thick * 0.5 + 0.75 - dist));
          this.setPixel(x, y, r, g, b, a * alpha);
        } else if (glowRadius > 0 && dist <= thick * 0.5 + glowRadius) {
          const glowFrac = (dist - thick * 0.5) / glowRadius;
          const glowAlpha = Math.exp(-glowFrac * 2.5) * a * 0.45;
          this.setPixel(x, y, r, g, b, glowAlpha);
        }
      }
    }
  }

  // Draw circle with glow
  drawCircle(cx, cy, radius, r, g, b, a, glowRadius = 0) {
    const minX = Math.max(0, Math.floor(cx - radius - glowRadius - 2));
    const maxX = Math.min(this.w - 1, Math.ceil(cx + radius + glowRadius + 2));
    const minY = Math.max(0, Math.floor(cy - radius - glowRadius - 2));
    const maxY = Math.min(this.h - 1, Math.ceil(cy + radius + glowRadius + 2));

    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        const dist = Math.hypot(x - cx, y - cy);
        if (dist <= radius + 0.75) {
          const alpha = Math.max(0.0, Math.min(1.0, radius + 0.75 - dist));
          this.setPixel(x, y, r, g, b, a * alpha);
        } else if (glowRadius > 0 && dist <= radius + glowRadius) {
          const glowFrac = (dist - radius) / glowRadius;
          const glowAlpha = Math.exp(-glowFrac * 2.2) * a * 0.5;
          this.setPixel(x, y, r, g, b, glowAlpha);
        }
      }
    }
  }

  // Radial glow burst
  drawRadialGlow(cx, cy, radius, r, g, b, peakAlpha) {
    const minX = Math.max(0, Math.floor(cx - radius));
    const maxX = Math.min(this.w - 1, Math.ceil(cx + radius));
    const minY = Math.max(0, Math.floor(cy - radius));
    const maxY = Math.min(this.h - 1, Math.ceil(cy + radius));

    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        const d = Math.hypot(x - cx, y - cy) / radius;
        if (d < 1.0) {
          const alpha = Math.exp(-d * 3.0) * peakAlpha;
          this.setPixel(x, y, r, g, b, alpha);
        }
      }
    }
  }
}

// Generate the high-tech Icon
function renderElectricFlowIcon(w = 512, h = 512, transparentBg = false) {
  const canvas = new PixelCanvas(w, h);
  const cx = w * 0.5;
  const cy = h * 0.5;

  if (!transparentBg) {
    // 1. Base Squircle with Deep Cyber Gradient
    const margin = 16;
    const cornerR = 105;
    canvas.drawRoundedRect(margin, margin, w - margin, h - margin, cornerR, (x, y, u, v) => {
      // Radial + vertical gradient
      const dy = v - 0.45;
      const dx = u - 0.5;
      const rDist = Math.hypot(dx, dy);
      
      // Top deep cyan-navy #061933, center illuminated #0b2f56, bottom deep #020914
      let r = 0.03 + (1.0 - rDist) * 0.05;
      let g = 0.10 + (1.0 - rDist) * 0.14 - v * 0.05;
      let b = 0.22 + (1.0 - rDist) * 0.24 - v * 0.08;
      
      // Subtle top inner highlight
      if (v < 0.2) {
        const topH = (0.2 - v) / 0.2;
        r += topH * 0.08;
        g += topH * 0.18;
        b += topH * 0.25;
      }
      return [r, g, b, 1.0];
    });

    // 2. Beveled Metallic Border
    const borderThick = 5.0;
    const bMargin = margin + 2;
    for (let y = bMargin; y <= h - bMargin; y++) {
      for (let x = bMargin; x <= w - bMargin; x++) {
        const qx = Math.abs(x - cx) - ((w - 2 * bMargin) * 0.5 - cornerR);
        const qy = Math.abs(y - cy) - ((h - 2 * bMargin) * 0.5 - cornerR);
        const mx = Math.max(qx, 0.0);
        const my = Math.max(qy, 0.0);
        const dist = Math.sqrt(mx * mx + my * my) + Math.min(Math.max(qx, qy), 0.0) - cornerR;
        if (Math.abs(dist) <= borderThick * 0.5) {
          const edgeAlpha = 1.0 - Math.abs(dist) / (borderThick * 0.5);
          // Cyan neon rim
          const rimColor = y < cy ? [0.2, 0.9, 1.0, 0.95] : [0.0, 0.5, 0.8, 0.8];
          canvas.setPixel(x, y, rimColor[0], rimColor[1], rimColor[2], rimColor[3] * edgeAlpha);
        }
      }
    }
  }

  // 3. Cybernetic Circuit Traces (Neon Cyan & Electric Gold)
  const circuits = [
    // Left-side traces
    [[45, 140], [130, 140], [180, 190], [180, 230]],
    [[45, 256], [140, 256]],
    [[45, 370], [130, 370], [180, 320], [180, 280]],
    // Right-side traces
    [[467, 140], [382, 140], [332, 190], [332, 230]],
    [[467, 256], [372, 256]],
    [[467, 370], [382, 370], [332, 320], [332, 280]],
    // Top & bottom feeder traces
    [[256, 45], [256, 120]],
    [[256, 467], [256, 395]]
  ];

  for (const pts of circuits) {
    for (let i = 0; i < pts.length - 1; i++) {
      const p1 = pts[i];
      const p2 = pts[i + 1];
      // Cyan track with neon glow
      canvas.drawLine(p1[0], p1[1], p2[0], p2[1], 4.5, 0.0, 0.88, 1.0, 0.95, 12);
    }
    // Solder pads at end
    const end = pts[0];
    canvas.drawCircle(end[0], end[1], 5.0, 1.0, 0.85, 0.2, 1.0, 8);
    const mid = pts[pts.length - 1];
    canvas.drawCircle(mid[0], mid[1], 4.5, 0.0, 1.0, 0.95, 8);
  }

  // 4. Central Radial Energy Bloom (Warm Cyan & Gold Core)
  canvas.drawRadialGlow(cx, cy - 25, 230, 0.0, 0.75, 1.0, 0.45);
  canvas.drawRadialGlow(cx, cy - 25, 140, 0.2, 0.9, 1.0, 0.65);
  canvas.drawRadialGlow(cx, cy - 25, 80, 1.0, 0.95, 0.6, 0.85);

  // 5. Electric Bulb Glass Body (Bulbous Head + Neck)
  const bulbCenterY = cy - 45;
  const bulbRadius = 96;

  // Outer glass glow & rim
  for (let y = Math.floor(bulbCenterY - bulbRadius - 10); y <= Math.ceil(bulbCenterY + bulbRadius + 40); y++) {
    for (let x = Math.floor(cx - bulbRadius - 10); x <= Math.ceil(cx + bulbRadius + 10); x++) {
      // Pear-shaped distance calculation
      let relY = y - bulbCenterY;
      let effectiveRadius = bulbRadius;
      if (relY > 20) {
        // Taper inward towards the screw base
        const taper = Math.min(1.0, (relY - 20) / 70);
        effectiveRadius = bulbRadius - taper * 45;
      }
      const dist = Math.hypot(x - cx, y - bulbCenterY);
      const pearDist = Math.hypot(x - cx, (y - bulbCenterY) * 0.95) - effectiveRadius;

      if (pearDist <= 0 && pearDist >= -8) {
        // Glass rim
        const alpha = Math.exp(pearDist * 0.25) * 0.7;
        canvas.setPixel(x, y, 0.6, 0.92, 1.0, alpha);
      } else if (pearDist < -8 && pearDist >= -effectiveRadius) {
        // Soft blue inner glow
        const innerFrac = (-pearDist - 8) / (effectiveRadius - 8);
        const fillAlpha = (1.0 - innerFrac) * 0.22;
        canvas.setPixel(x, y, 0.1, 0.6, 0.95, fillAlpha);
      }
    }
  }

  // Glass specular highlight arc (Top-left curve)
  for (let angle = -2.4; angle <= -1.2; angle += 0.02) {
    const hx = cx + Math.cos(angle) * (bulbRadius - 12);
    const hy = bulbCenterY + Math.sin(angle) * (bulbRadius - 12);
    canvas.drawCircle(hx, hy, 4.0, 1.0, 1.0, 1.0, 0.85, 4);
  }

  // 6. Brass Screw Base & Ceramic Contact Tip
  const baseTopY = bulbCenterY + 85;
  const baseWidth = 52;
  const baseHeight = 44;

  // Horizontal thread ridges
  for (let t = 0; t < 3; t++) {
    const threadY = baseTopY + t * 12;
    canvas.drawLine(cx - baseWidth * 0.5, threadY, cx + baseWidth * 0.5, threadY, 7.5, 0.9, 0.7, 0.25, 0.95, 3);
    canvas.drawLine(cx - baseWidth * 0.45, threadY - 1, cx + baseWidth * 0.45, threadY - 1, 3.0, 1.0, 0.9, 0.55, 0.9);
  }
  // Bottom black ceramic insulator + contact pin
  canvas.drawCircle(cx, baseTopY + baseHeight + 4, 11, 0.15, 0.18, 0.22, 1.0);
  canvas.drawCircle(cx, baseTopY + baseHeight + 6, 6, 0.8, 0.85, 0.9, 1.0, 4);

  // 7. High-Voltage Glowing Lightning Filament (Central Energy Core)
  // Dynamic zigzag lightning shape
  const bolt = [
    [cx + 8, bulbCenterY - 60],
    [cx - 24, bulbCenterY - 15],
    [cx + 2, bulbCenterY - 10],
    [cx - 30, bulbCenterY + 45],
    [cx + 28, bulbCenterY - 2],
    [cx + 2, bulbCenterY + 2],
    [cx + 22, bulbCenterY - 38],
    [cx + 8, bulbCenterY - 60]
  ];

  // Draw intense thick lightning bolt with layered glows
  // Layer 1: Wide electric cyan glow aura
  for (let i = 0; i < bolt.length - 1; i++) {
    canvas.drawLine(bolt[i][0], bolt[i][1], bolt[i+1][0], bolt[i+1][1], 12.0, 0.0, 0.8, 1.0, 0.7, 24);
  }
  // Layer 2: Vivid golden-yellow energy beam
  for (let i = 0; i < bolt.length - 1; i++) {
    canvas.drawLine(bolt[i][0], bolt[i][1], bolt[i+1][0], bolt[i+1][1], 7.0, 1.0, 0.85, 0.15, 0.95, 8);
  }
  // Layer 3: Blinding white-hot core
  for (let i = 0; i < bolt.length - 1; i++) {
    canvas.drawLine(bolt[i][0], bolt[i][1], bolt[i+1][0], bolt[i+1][1], 3.2, 1.0, 1.0, 1.0, 1.0, 2);
  }

  // 8. Radiating Electric Sparks & Star Flares
  const sparks = [
    [cx - 80, bulbCenterY - 30, 9, 1.0, 0.9, 0.2],
    [cx + 82, bulbCenterY - 25, 8, 0.1, 0.95, 1.0],
    [cx - 65, bulbCenterY + 45, 6, 0.2, 0.85, 1.0],
    [cx + 70, bulbCenterY + 40, 7, 1.0, 0.85, 0.2],
    [cx, bulbCenterY - 88, 8, 1.0, 1.0, 0.8],
    [cx - 40, bulbCenterY - 75, 5, 0.2, 0.95, 1.0],
    [cx + 45, bulbCenterY - 72, 6, 1.0, 0.9, 0.3]
  ];

  for (const [sx, sy, sr, sR, sG, sB] of sparks) {
    // 4-point diamond star flare
    canvas.drawCircle(sx, sy, sr * 0.4, 1.0, 1.0, 1.0, 1.0, 6);
    canvas.drawLine(sx - sr * 2.0, sy, sx + sr * 2.0, sy, 1.5, sR, sG, sB, 0.95, 3);
    canvas.drawLine(sx, sy - sr * 2.0, sx, sy + sr * 2.0, 1.5, sR, sG, sB, 0.95, 3);
  }

  // 9. Bottom Cybernetic "ELECTRIC FLOW" Badge Accent
  // Sleek cyber plate with cyan pulse
  const badgeY = h - 72;
  const badgeW = 260;
  const badgeH = 24;
  canvas.drawRoundedRect(cx - badgeW * 0.5, badgeY - badgeH * 0.5, cx + badgeW * 0.5, badgeY + badgeH * 0.5, 12, (x, y, u, v) => {
    return [0.03, 0.12, 0.24, 0.85];
  });
  // Border of badge
  canvas.drawLine(cx - badgeW * 0.5 + 4, badgeY - badgeH * 0.5, cx + badgeW * 0.5 - 4, badgeY - badgeH * 0.5, 2, 0.0, 0.85, 1.0, 0.9, 4);
  canvas.drawLine(cx - badgeW * 0.5 + 4, badgeY + badgeH * 0.5, cx + badgeW * 0.5 - 4, badgeY + badgeH * 0.5, 2, 0.0, 0.85, 1.0, 0.9, 4);
  // Central indicator pulse
  canvas.drawCircle(cx, badgeY, 4.0, 0.0, 1.0, 0.8, 1.0, 8);
  canvas.drawCircle(cx - 50, badgeY, 2.5, 1.0, 0.8, 0.2, 0.85, 4);
  canvas.drawCircle(cx + 50, badgeY, 2.5, 1.0, 0.8, 0.2, 0.85, 4);

  return encodePNG(w, h, canvas.buf);
}

// Generate matching Vector SVG
function generateVectorSVG() {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <!-- Background Gradient -->
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#081a38"/>
      <stop offset="50%" stop-color="#0d2e54"/>
      <stop offset="100%" stop-color="#030a16"/>
    </linearGradient>

    <!-- Metallic Rim Gradient -->
    <linearGradient id="rimGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00f0ff"/>
      <stop offset="50%" stop-color="#0088cc"/>
      <stop offset="100%" stop-color="#003366"/>
    </linearGradient>

    <!-- Glow Radial -->
    <radialGradient id="coreBloom" cx="50%" cy="42%" r="48%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.95"/>
      <stop offset="20%" stop-color="#ffd54f" stop-opacity="0.85"/>
      <stop offset="55%" stop-color="#00e5ff" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#004488" stop-opacity="0"/>
    </radialGradient>

    <!-- Lightning Filament Gradient -->
    <linearGradient id="boltGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="45%" stop-color="#fff59d"/>
      <stop offset="100%" stop-color="#ffb300"/>
    </linearGradient>

    <!-- Brass Threads -->
    <linearGradient id="brassGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#8d6e63"/>
      <stop offset="35%" stop-color="#ffd54f"/>
      <stop offset="70%" stop-color="#ffb300"/>
      <stop offset="100%" stop-color="#5d4037"/>
    </linearGradient>

    <!-- Drop Glow Filter -->
    <filter id="neonGlow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="8" result="blur1"/>
      <feGaussianBlur stdDeviation="18" result="blur2"/>
      <feMerge>
        <feMergeNode in="blur2"/>
        <feMergeNode in="blur1"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>

    <filter id="intenseGlow" x="-80%" y="-80%" width="260%" height="260%">
      <feGaussianBlur stdDeviation="14" result="b1"/>
      <feGaussianBlur stdDeviation="28" result="b2"/>
      <feMerge>
        <feMergeNode in="b2"/>
        <feMergeNode in="b1"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <!-- App Squircle Base -->
  <rect x="16" y="16" width="480" height="480" rx="108" fill="url(#bgGrad)"/>
  <rect x="18" y="18" width="476" height="476" rx="106" fill="none" stroke="url(#rimGrad)" stroke-width="4.5" stroke-opacity="0.85"/>

  <!-- Radial Core Lighting -->
  <circle cx="256" cy="215" r="190" fill="url(#coreBloom)"/>

  <!-- Circuit Traces Left -->
  <g stroke="#00e5ff" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" filter="url(#neonGlow)">
    <polyline points="45,140 130,140 180,190 180,230" fill="none"/>
    <polyline points="45,256 145,256" fill="none"/>
    <polyline points="45,370 130,370 180,320 180,280" fill="none"/>
  </g>
  <!-- Circuit Traces Right -->
  <g stroke="#00e5ff" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" filter="url(#neonGlow)">
    <polyline points="467,140 382,140 332,190 332,230" fill="none"/>
    <polyline points="467,256 367,256" fill="none"/>
    <polyline points="467,370 382,370 332,320 332,280" fill="none"/>
  </g>
  <!-- Top & Bottom Feeder -->
  <g stroke="#00e5ff" stroke-width="4.5" stroke-linecap="round" filter="url(#neonGlow)">
    <line x1="256" y1="45" x2="256" y2="115"/>
    <line x1="256" y1="467" x2="256" y2="395"/>
  </g>

  <!-- Gold Terminal Nodes -->
  <circle cx="45" cy="140" r="6" fill="#ffd700" filter="url(#neonGlow)"/>
  <circle cx="45" cy="256" r="6" fill="#ffd700" filter="url(#neonGlow)"/>
  <circle cx="45" cy="370" r="6" fill="#ffd700" filter="url(#neonGlow)"/>
  <circle cx="467" cy="140" r="6" fill="#ffd700" filter="url(#neonGlow)"/>
  <circle cx="467" cy="256" r="6" fill="#ffd700" filter="url(#neonGlow)"/>
  <circle cx="467" cy="370" r="6" fill="#ffd700" filter="url(#neonGlow)"/>
  <circle cx="256" cy="45" r="6" fill="#ffd700" filter="url(#neonGlow)"/>
  <circle cx="256" cy="467" r="6" fill="#ffd700" filter="url(#neonGlow)"/>

  <!-- Bulb Outer Glass Envelope -->
  <path d="M 256,115
           C 195,115 160,158 160,215
           C 160,256 182,280 200,305
           L 200,325
           L 312,325
           L 312,305
           C 330,280 352,256 352,215
           C 352,158 317,115 256,115 Z"
        fill="#05264c" fill-opacity="0.35"
        stroke="#80d8ff" stroke-width="5" stroke-opacity="0.75" filter="url(#neonGlow)"/>

  <!-- Glass Specular Highlight -->
  <path d="M 185,160 A 85 85 0 0 1 240,126"
        fill="none" stroke="#ffffff" stroke-width="7" stroke-linecap="round" stroke-opacity="0.85"/>

  <!-- Brass Screw Base -->
  <rect x="206" y="325" width="100" height="14" rx="7" fill="url(#brassGrad)"/>
  <rect x="209" y="341" width="94" height="13" rx="6.5" fill="url(#brassGrad)"/>
  <rect x="214" y="356" width="84" height="13" rx="6.5" fill="url(#brassGrad)"/>
  <!-- Contact tip -->
  <ellipse cx="256" cy="374" rx="20" ry="7" fill="#212121"/>
  <ellipse cx="256" cy="376" rx="11" ry="4" fill="#cfd8dc" filter="url(#neonGlow)"/>

  <!-- High-Voltage Lightning Bolt Core -->
  <polygon points="268,142 208,218 252,222 216,298 304,212 260,208 288,142"
           fill="url(#boltGrad)" stroke="#ffffff" stroke-width="3.5" filter="url(#intenseGlow)"/>

  <!-- Electric Energy Sparks -->
  <g fill="#ffffff" filter="url(#neonGlow)">
    <circle cx="170" cy="180" r="5"/>
    <circle cx="340" cy="185" r="4.5"/>
    <circle cx="178" cy="270" r="4"/>
    <circle cx="335" cy="265" r="5.5"/>
    <polygon points="256,92 258,98 264,100 258,102 256,108 254,102 248,100 254,98" fill="#ffd700"/>
    <polygon points="140,225 142,229 146,230 142,231 140,235 138,231 134,230 138,229" fill="#00e5ff"/>
    <polygon points="372,220 374,224 378,225 374,226 372,230 370,226 366,225 370,224" fill="#00e5ff"/>
  </g>

  <!-- Bottom Brand Plate -->
  <rect x="126" y="425" width="260" height="26" rx="13" fill="#051c36" stroke="#00e5ff" stroke-width="2" filter="url(#neonGlow)"/>
  <circle cx="256" cy="438" r="5" fill="#00ffcc" filter="url(#neonGlow)"/>
  <circle cx="206" cy="438" r="3" fill="#ffd700"/>
  <circle cx="306" cy="438" r="3" fill="#ffd700"/>
</svg>`;
}

// Generate files
console.log('Generating Electric Flow professional game icons...');
const fullIconPNG = renderElectricFlowIcon(512, 512, false);
fs.writeFileSync('assets/generated/app-icon.png', fullIconPNG);
console.log('Saved assets/generated/app-icon.png (' + fullIconPNG.length + ' bytes)');

fs.writeFileSync('assets/generated/app-icon-safe.png', fullIconPNG);
console.log('Saved assets/generated/app-icon-safe.png');

const fgIconPNG = renderElectricFlowIcon(512, 512, true);
fs.writeFileSync('assets/generated/app-icon-foreground.png', fgIconPNG);
console.log('Saved assets/generated/app-icon-foreground.png (' + fgIconPNG.length + ' bytes)');

const vectorSVG = generateVectorSVG();
fs.writeFileSync('assets/generated/app-icon-background.svg', vectorSVG);
console.log('Saved assets/generated/app-icon-background.svg');

fs.writeFileSync('assets/generated/app-icon.svg', vectorSVG);
console.log('Saved assets/generated/app-icon.svg');

console.log('ALL ICONS GENERATED SUCCESSFULLY!');
