const fs = require('fs');

const DIR_UP = 1, DIR_RIGHT = 2, DIR_DOWN = 4, DIR_LEFT = 8;
const OPPOSITE = { [DIR_UP]: DIR_DOWN, [DIR_DOWN]: DIR_UP, [DIR_LEFT]: DIR_RIGHT, [DIR_RIGHT]: DIR_LEFT };
const OFFSETS = { [DIR_UP]: [-1, 0], [DIR_DOWN]: [1, 0], [DIR_LEFT]: [0, -1], [DIR_RIGHT]: [0, 1] };

function rotatePorts(ports, rot) {
  let res = ports;
  rot = (rot % 4 + 4) % 4;
  for (let s = 0; s < rot; s++) {
    let next = 0;
    if (res & DIR_UP) next |= DIR_RIGHT;
    if (res & DIR_RIGHT) next |= DIR_DOWN;
    if (res & DIR_DOWN) next |= DIR_LEFT;
    if (res & DIR_LEFT) next |= DIR_UP;
    res = next;
  }
  return res;
}

const BASE_PORTS = {
  0: 0,                           // EMPTY
  1: DIR_UP | DIR_DOWN,           // WIRE_STRAIGHT
  2: DIR_DOWN | DIR_RIGHT,        // WIRE_CORNER
  3: DIR_UP | DIR_RIGHT | DIR_DOWN,// WIRE_TEE
  4: 15,                          // WIRE_CROSS
  5: DIR_UP,                      // BATTERY
  6: 15,                          // BULB
  7: DIR_UP,                      // SOLAR
  8: DIR_UP | DIR_DOWN,           // RESISTOR
  9: 15,                          // HEATER
  10: DIR_UP | DIR_DOWN,          // CAPACITOR
  11: 15,                         // FAN
  12: 15,                         // VACUUM_TUBE
  13: 15                          // TESLA_COIL
};

function getActivePorts(tile) {
  if (tile.ports !== undefined) {
    return rotatePorts(tile.ports, tile.rot || 0);
  }
  const base = BASE_PORTS[tile.type] || 0;
  return rotatePorts(base, tile.rot || 0);
}

const data = JSON.parse(fs.readFileSync('assets/data/electric_levels.json', 'utf8'));

for (const lvlObj of data.levels) {
  const lvl = lvlObj.level;
  const rows = lvlObj.rows;
  const cols = lvlObj.cols;
  const tiles = lvlObj.tiles;
  const declaredMin = lvlObj.min_moves;

  const total = rows * cols;
  const emptyCount = tiles.filter(t => t.type === 0).length;

  // Check initial power state
  let queue = [];
  let visited = new Set();
  let powered = new Set();

  for (let i = 0; i < tiles.length; i++) {
    if (tiles[i].type === 5 || tiles[i].type === 7) {
      queue.push(i);
      visited.add(i);
    }
  }

  while (queue.length > 0) {
    const cur = queue.shift();
    const r = Math.floor(cur / cols);
    const c = cur % cols;
    const p = getActivePorts(tiles[cur]);

    for (const d of [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT]) {
      if ((p & d) === 0) continue;
      const nr = r + OFFSETS[d][0];
      const nc = c + OFFSETS[d][1];
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      const nIdx = nr * cols + nc;
      if (tiles[nIdx].type === 0) continue;
      const nP = getActivePorts(tiles[nIdx]);
      if ((nP & OPPOSITE[d]) === 0) continue;

      powered.add(nIdx);
      if (!visited.has(nIdx) && tiles[nIdx].type !== 5 && tiles[nIdx].type !== 7) {
        visited.add(nIdx);
        queue.push(nIdx);
      }
    }
  }

  const targets = tiles.map((t, idx) => ({ t, idx })).filter(item => [6, 9, 11, 12, 13].includes(item.t.type));
  const litTargets = targets.filter(item => powered.has(item.idx)).length;

  console.log(`Lvl ${lvl} [OK]: size=${rows}x${cols}, tiles=${total}, empty=${emptyCount}, rotatable=${tiles.filter(t => t.rotatable).length}, targets=${targets.length}, initiallyLit=${litTargets}, minMoves=${declaredMin}`);
}
