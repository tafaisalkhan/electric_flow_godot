const DIR_UP = 1, DIR_RIGHT = 2, DIR_DOWN = 4, DIR_LEFT = 8;
const OPPOSITE = { [DIR_UP]: DIR_DOWN, [DIR_DOWN]: DIR_UP, [DIR_LEFT]: DIR_RIGHT, [DIR_RIGHT]: DIR_LEFT };
const OFFSETS = { [DIR_UP]: [-1, 0], [DIR_DOWN]: [1, 0], [DIR_LEFT]: [0, -1], [DIR_RIGHT]: [0, 1] };

function rotatePorts(ports, rot) {
  let res = 0;
  for (let b = 0; b < 4; b++) {
    if (ports & (1 << b)) res |= (1 << ((b + rot) % 4));
  }
  return res;
}

const BASE_PORTS = {
  EMPTY: 0,
  WIRE_STRAIGHT: DIR_UP | DIR_DOWN,
  WIRE_CORNER: DIR_UP | DIR_RIGHT,
  WIRE_TEE: DIR_UP | DIR_RIGHT | DIR_DOWN,
  BATTERY: DIR_UP,
  BULB: DIR_UP | DIR_RIGHT | DIR_DOWN | DIR_LEFT,
};

function getActivePorts(type, rot) {
  return rotatePorts(BASE_PORTS[type] || 0, rot);
}

const solved = [
  { type: "BATTERY", rot: 1, rotatable: false, channel: 1 },
  { type: "WIRE_TEE", rot: 1, rotatable: true },
  { type: "WIRE_CORNER", rot: 2, rotatable: true },

  { type: "BULB", rot: 0, rotatable: false, channel: 1 },
  { type: "WIRE_CORNER", rot: 3, rotatable: true },
  { type: "WIRE_STRAIGHT", rot: 0, rotatable: true },

  { type: "EMPTY", rot: 0, rotatable: false },
  { type: "EMPTY", rot: 0, rotatable: false },
  { type: "BULB", rot: 0, rotatable: false, channel: 1 }
];

const rotIndices = [1, 2, 4, 5];

function checkSolve(tiles) {
  const rows = 3, cols = 3;
  const queue = [{ idx: 0, ch: 1 }];
  const visited = new Set(["0:1"]);
  const powered = new Set([0]);

  while (queue.length > 0) {
    const { idx, ch } = queue.shift();
    const r = Math.floor(idx / cols);
    const c = idx % cols;
    const currPorts = getActivePorts(tiles[idx].type, tiles[idx].rot);

    for (const dir of [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT]) {
      if ((currPorts & dir) === 0) continue;
      const [dr, dc] = OFFSETS[dir];
      const nr = r + dr, nc = c + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      const nIdx = nr * cols + nc;
      const nTile = tiles[nIdx];
      if (nTile.type === "EMPTY") continue;

      const opp = OPPOSITE[dir];
      const nPorts = getActivePorts(nTile.type, nTile.rot);
      if ((nPorts & opp) === 0) continue;

      powered.add(nIdx);
      const key = nIdx + ":" + ch;
      if (!visited.has(key)) {
        visited.add(key);
        if (nTile.type !== "BATTERY" && nTile.type !== "BULB") {
          queue.push({ idx: nIdx, ch });
        }
      }
    }
  }

  const targets = [3, 8];
  return targets.every(idx => powered.has(idx)) && powered.size === 7;
}

for (let s1 = 0; s1 < 4; s1++) {
  for (let s2 = 0; s2 < 4; s2++) {
    for (let s4 = 0; s4 < 4; s4++) {
      for (let s5 = 0; s5 < 4; s5++) {
        const init = solved.map(t => ({ ...t }));
        init[1].rot = s1;
        init[2].rot = s2;
        init[4].rot = s4;
        init[5].rot = s5;
        if (checkSolve(init)) continue;

        let minClicks = Infinity;
        for (let c = 0; c < 256; c++) {
          let temp = c;
          const test = init.map(t => ({ ...t }));
          let clicks = 0;
          for (let i = 0; i < rotIndices.length; i++) {
            const r = temp % 4;
            temp = Math.floor(temp / 4);
            test[rotIndices[i]].rot = r;
            const diff = (r - init[rotIndices[i]].rot + 4) % 4;
            clicks += diff;
          }
          if (checkSolve(test)) {
            if (clicks < minClicks) minClicks = clicks;
          }
        }
        if (minClicks === 3) {
          console.log(`Scramble found! s1=${s1}, s2=${s2}, s4=${s4}, s5=${s5}, minClicks=3`);
          process.exit(0);
        }
      }
    }
  }
}
