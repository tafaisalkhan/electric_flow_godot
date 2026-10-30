// Test applause audio generator
const sample_rate = 22050;
const duration = 1.8;
const total_samples = Math.floor(sample_rate * duration);
const buffer = new Float32Array(total_samples);

// Generate 32 clap events
const claps = [];
let t = 0.05;
for (let c = 0; c < 34; c++) {
  // Claps staggered every 0.03 - 0.08 seconds with random jitter
  t += 0.03 + (Math.sin(c * 17.3) * 0.5 + 0.5) * 0.05;
  if (t > duration - 0.1) break;
  const clap_dur = 0.035 + (Math.sin(c * 23.7) * 0.5 + 0.5) * 0.025;
  const clap_freq = 650.0 + (Math.sin(c * 41.1) * 0.5 + 0.5) * 550.0;
  const clap_vol = 0.25 + (Math.sin(c * 13.9) * 0.5 + 0.5) * 0.35;
  claps.push({ start: t, dur: clap_dur, freq: clap_freq, vol: clap_vol });
}

console.log(`Generated ${claps.length} clap events`);

// Synthesize claps into buffer
for (const clap of claps) {
  const start_sample = Math.floor(clap.start * sample_rate);
  const dur_samples = Math.floor(clap.dur * sample_rate);
  for (let i = 0; i < dur_samples; i++) {
    const idx = start_sample + i;
    if (idx >= total_samples) break;
    const ct = i / sample_rate;
    // Attack 2ms, exponential decay
    const attack = Math.min(1.0, ct / 0.002);
    const decay = Math.exp(-ct * 65.0);
    const env = attack * decay;
    // Noise + slap tone resonance
    const noise = ((Math.sin((start_sample + i) * 8931.23) * 43758.5453) % 1.0) * 2.0 - 1.0;
    const tone = Math.sin(2.0 * Math.PI * clap.freq * ct);
    const sample = (noise * 0.7 + tone * 0.3) * env * clap.vol;
    buffer[idx] += sample;
  }
}

// Find peak
let peak = 0;
for (let i = 0; i < total_samples; i++) {
  const abs = Math.abs(buffer[i]);
  if (abs > peak) peak = abs;
}
console.log(`Peak amplitude before normalization: ${peak.toFixed(3)}`);
// Normalize if peak > 0.95
const norm = peak > 0.95 ? 0.95 / peak : 1.0;
let clipped = 0;
for (let i = 0; i < total_samples; i++) {
  buffer[i] *= norm;
  if (Math.abs(buffer[i]) > 1.0) clipped++;
}
console.log(`Post-normalization peak: ${(peak * norm).toFixed(3)}, clipped samples: ${clipped}`);
