const fs = require('fs');

const DIR_UP = 1, DIR_RIGHT = 2, DIR_DOWN = 4, DIR_LEFT = 8;
const OPPOSITE = { [DIR_UP]: DIR_DOWN, [DIR_DOWN]: DIR_UP, [DIR_LEFT]: DIR_RIGHT, [DIR_RIGHT]: DIR_LEFT };
const OFFSETS = { [DIR_UP]: [-1, 0], [DIR_DOWN]: [1, 0], [DIR_LEFT]: [0, -1], [DIR_RIGHT]: [0, 1] };

function rotate_mask_cw(mask, steps = 1) {
  let result = mask;
  steps = (steps % 4 + 4) % 4;
  for (let i = 0; i < steps; i++) {
    let next = 0;
    if ((result & DIR_UP) !== 0) next |= DIR_RIGHT;
    if ((result & DIR_RIGHT) !== 0) next |= DIR_DOWN;
    if ((result & DIR_DOWN) !== 0) next |= DIR_LEFT;
    if ((result & DIR_LEFT) !== 0) next |= DIR_UP;
    result = next;
  }
  return result;
}

const BASE_PORTS = {
  EMPTY: 0,
  WIRE_STRAIGHT: DIR_UP | DIR_DOWN,
  WIRE_CORNER: DIR_DOWN | DIR_RIGHT, // DOWN + RIGHT
  WIRE_TEE: DIR_UP | DIR_RIGHT | DIR_DOWN, // UP + RIGHT + DOWN
  WIRE_CROSS: DIR_UP | DIR_RIGHT | DIR_DOWN | DIR_LEFT,
  BATTERY: DIR_UP,
  BULB: DIR_UP | DIR_RIGHT | DIR_DOWN | DIR_LEFT,
  SOLAR: DIR_UP,
  RESISTOR: DIR_UP | DIR_DOWN,
  HEATER: DIR_UP | DIR_RIGHT | DIR_DOWN | DIR_LEFT,
  CAPACITOR: DIR_UP | DIR_DOWN,
  FAN: DIR_UP | DIR_RIGHT | DIR_DOWN | DIR_LEFT,
  VACUUM_TUBE: DIR_UP | DIR_RIGHT | DIR_DOWN | DIR_LEFT,
  TESLA_COIL: DIR_UP | DIR_RIGHT | DIR_DOWN | DIR_LEFT,
};

function getActivePorts(tile) {
  if (tile.ports !== undefined) {
    return rotate_mask_cw(tile.ports, tile.rot || 0);
  }
  const base = BASE_PORTS[tile.type] || 0;
  return rotate_mask_cw(base, tile.rot || 0);
}

function evaluate(rows, cols, tiles) {
  const queue = [];
  const visited = new Set();
  const powered = new Set();

  tiles.forEach((t, idx) => {
    if (t.type === 'BATTERY' || t.type === 'SOLAR') {
      powered.add(idx);
      queue.push({ idx, ch: t.channel });
      visited.add(idx + ':' + t.channel);
    }
  });

  while (queue.length > 0) {
    const { idx, ch } = queue.shift();
    const r = Math.floor(idx / cols);
    const c = idx % cols;
    const currPorts = getActivePorts(tiles[idx]);

    for (const dir of [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT]) {
      if ((currPorts & dir) === 0) continue;
      const [dr, dc] = OFFSETS[dir];
      const nr = r + dr, nc = c + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      const nIdx = nr * cols + nc;
      const nTile = tiles[nIdx];
      if (nTile.type === 'EMPTY') continue;

      const opp = OPPOSITE[dir];
      const nPorts = getActivePorts(nTile);
      if ((nPorts & opp) === 0) continue;

      if (nTile.channel && nTile.channel !== ch && nTile.channel !== 'NONE') continue;

      powered.add(nIdx);
      const key = nIdx + ':' + ch;
      if (!visited.has(key)) {
        visited.add(key);
        if (nTile.type !== 'BATTERY' && nTile.type !== 'SOLAR' && nTile.type !== 'BULB') {
          queue.push({ idx: nIdx, ch });
        }
      }
    }
  }

  const targets = [];
  tiles.forEach((t, idx) => {
    if (['BULB', 'FAN', 'HEATER', 'VACUUM_TUBE', 'TESLA_COIL'].includes(t.type)) {
      targets.push(idx);
    }
  });

  const litCount = targets.filter(idx => powered.has(idx)).length;
  const isSolved = targets.length > 0 && litCount === targets.length;
  const totalNonEmpty = tiles.filter(t => t.type !== 'EMPTY').length;
  const isFullCircuit = powered.size === totalNonEmpty;

  return { isSolved, litCount, targetCount: targets.length, poweredCount: powered.size, totalNonEmpty, isFullCircuit };
}

// Design Level 9: 4x4, Single Circuit (CYAN). 1 Battery, 1 Fan, 1 Bulb.
// Layout:
// Row 0: BATTERY (0,0) rot=1 (RIGHT) -> WIRE_STRAIGHT (0,1) -> WIRE_TEE (0,2) -> BULB (0,3)
// Row 1: EMPTY (1,0)                -> EMPTY (1,1)         -> WIRE_STRAIGHT (1,2) -> EMPTY (1,3)
// Row 2: EMPTY (2,0)                -> EMPTY (2,1)         -> WIRE_CORNER (2,2) -> FAN (2,3)
// Row 3: EMPTY (3,0..3)
// Solved ports:
// (0,0) BATTERY rot 1 -> RIGHT
// (0,1) WIRE_STRAIGHT rot 1 -> RIGHT+LEFT
// (0,2) WIRE_TEE rot 1 -> RIGHT+DOWN+LEFT
// (0,3) BULB rot 0
// (1,2) WIRE_STRAIGHT rot 0 -> UP+DOWN
// (2,2) WIRE_CORNER: needs UP + RIGHT -> rot 3
// (2,3) FAN rot 0
const lvl9_solved = [
  { type: 'BATTERY', channel: 'CYAN', rot: 1, rotatable: false },
  { type: 'WIRE_STRAIGHT', rot: 1, rotatable: true }, // rot 1 (LEFT+RIGHT)
  { type: 'WIRE_TEE', rot: 1, rotatable: true },      // rot 1 (LEFT+RIGHT+DOWN)
  { type: 'BULB', channel: 'CYAN', rot: 0, rotatable: false },

  { type: 'EMPTY', rot: 0, rotatable: false },
  { type: 'EMPTY', rot: 0, rotatable: false },
  { type: 'WIRE_STRAIGHT', rot: 0, rotatable: true }, // rot 0 (UP+DOWN)
  { type: 'EMPTY', rot: 0, rotatable: false },

  { type: 'EMPTY', rot: 0, rotatable: false },
  { type: 'EMPTY', rot: 0, rotatable: false },
  { type: 'WIRE_CORNER', rot: 3, rotatable: true },   // rot 3 (UP+RIGHT)
  { type: 'FAN', channel: 'CYAN', rot: 0, rotatable: false },

  { type: 'EMPTY', rot: 0, rotatable: false },
  { type: 'EMPTY', rot: 0, rotatable: false },
  { type: 'EMPTY', rot: 0, rotatable: false },
  { type: 'EMPTY', rot: 0, rotatable: false }
];

console.log('Level 9 solved check:', evaluate(4, 4, lvl9_solved));
