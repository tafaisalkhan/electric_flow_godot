const fs = require('fs');

const TileType = {
  EMPTY: 0,
  WIRE_STRAIGHT: 1,
  WIRE_CORNER: 2,
  WIRE_TEE: 3,
  WIRE_CROSS: 4,
  BATTERY: 5,
  BULB: 6,
  SOLAR: 7,
  RESISTOR: 8,
  HEATER: 9,
  CAPACITOR: 10,
  FAN: 11,
  VACUUM_TUBE: 12,
  TESLA_COIL: 13
};

const Channel = {
  NONE: 0,
  CYAN: 1,
  YELLOW: 2,
  ORANGE: 3,
  MAGENTA: 4,
  GREEN: 5
};

const DIR_UP = 1;
const DIR_RIGHT = 2;
const DIR_DOWN = 4;
const DIR_LEFT = 8;
const DIR_ALL = 15;

function rotateMask(mask, steps) {
  let result = mask;
  steps = (steps % 4 + 4) % 4;
  for (let i = 0; i < steps; i++) {
    let next = 0;
    if (result & DIR_UP) next |= DIR_RIGHT;
    if (result & DIR_RIGHT) next |= DIR_DOWN;
    if (result & DIR_DOWN) next |= DIR_LEFT;
    if (result & DIR_LEFT) next |= DIR_UP;
    result = next;
  }
  return result;
}

function getBasePorts(type) {
  switch (type) {
    case TileType.WIRE_STRAIGHT: return DIR_UP | DIR_DOWN;
    case TileType.WIRE_CORNER: return DIR_DOWN | DIR_RIGHT;
    case TileType.WIRE_TEE: return DIR_UP | DIR_RIGHT | DIR_DOWN;
    case TileType.WIRE_CROSS: return DIR_ALL;
    case TileType.BATTERY: return DIR_UP;
    case TileType.SOLAR: return DIR_UP;
    case TileType.BULB: return DIR_ALL;
    case TileType.RESISTOR: return DIR_UP | DIR_DOWN;
    case TileType.HEATER: return DIR_ALL;
    case TileType.CAPACITOR: return DIR_UP | DIR_DOWN;
    case TileType.FAN: return DIR_ALL;
    case TileType.VACUUM_TUBE: return DIR_ALL;
    case TileType.TESLA_COIL: return DIR_ALL;
    default: return 0;
  }
}

function getOpposite(d) {
  if (d === DIR_UP) return DIR_DOWN;
  if (d === DIR_RIGHT) return DIR_LEFT;
  if (d === DIR_DOWN) return DIR_UP;
  if (d === DIR_LEFT) return DIR_RIGHT;
  return 0;
}

function getOffset(d) {
  if (d === DIR_UP) return [-1, 0];
  if (d === DIR_RIGHT) return [0, 1];
  if (d === DIR_DOWN) return [1, 0];
  if (d === DIR_LEFT) return [0, -1];
  return [0, 0];
}

function isTarget(type) {
  return [TileType.BULB, TileType.HEATER, TileType.FAN, TileType.VACUUM_TUBE, TileType.TESLA_COIL].includes(type);
}

function isSource(type) {
  return type === TileType.BATTERY || type === TileType.SOLAR;
}

function evaluateCircuit(level, tileRotations) {
  const { rows, cols, tiles } = level;
  const isPowered = new Array(tiles.length).fill(false);
  const queue = [];
  const visited = {};
  
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const idx = r * cols + c;
      const t = tiles[idx];
      if (isSource(t.type)) {
        queue.push({ r, c, ch: t.channel });
        visited[`${r},${c}`] = new Set([t.channel]);
        isPowered[idx] = true;
      }
    }
  }
  
  function getConnectedPorts(idx, r, c) {
    const t = tiles[idx];
    if (t.type === TileType.EMPTY) return 0;
    const base = t.ports ? t.ports : getBasePorts(t.type);
    const rot = tileRotations[idx];
    return rotateMask(base, rot);
  }
  
  const dirs = [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT];
  
  while (queue.length > 0) {
    const curr = queue.shift();
    const currIdx = curr.r * cols + curr.c;
    const currPorts = getConnectedPorts(currIdx, curr.r, curr.c);
    
    for (const d of dirs) {
      if ((currPorts & d) !== 0) {
        const [dr, dc] = getOffset(d);
        const nr = curr.r + dr;
        const nc = curr.c + dc;
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        
        const nIdx = nr * cols + nc;
        const nTile = tiles[nIdx];
        if (nTile.type === TileType.EMPTY) continue;
        
        const oppDir = getOpposite(d);
        const nPorts = getConnectedPorts(nIdx, nr, nc);
        
        if ((nPorts & oppDir) !== 0) {
          const nKey = `${nr},${nc}`;
          if (!visited[nKey]) visited[nKey] = new Set();
          
          if (nTile.type === TileType.BULB) {
            if (nTile.channel === Channel.NONE || nTile.channel === curr.ch) {
              isPowered[nIdx] = true;
            }
          } else if ([TileType.HEATER, TileType.FAN, TileType.VACUUM_TUBE, TileType.TESLA_COIL].includes(nTile.type)) {
            if (nTile.channel === Channel.NONE || nTile.channel === curr.ch) {
              isPowered[nIdx] = true;
              if (!visited[nKey].has(curr.ch)) {
                visited[nKey].add(curr.ch);
                queue.push({ r: nr, c: nc, ch: curr.ch });
              }
            }
          } else if (!isSource(nTile.type)) {
            if (!visited[nKey].has(curr.ch)) {
              visited[nKey].add(curr.ch);
              isPowered[nIdx] = true;
              queue.push({ r: nr, c: nc, ch: curr.ch });
            }
          }
        }
      }
    }
  }
  
  for (let i = 0; i < tiles.length; i++) {
    if (isTarget(tiles[i].type)) {
      if (!isPowered[i]) return false;
    }
  }
  return true;
}

function solveLevel(level) {
  const { tiles } = level;
  const rotatableIndices = [];
  const currentRotations = tiles.map(t => t.rot || 0);
  
  for (let i = 0; i < tiles.length; i++) {
    if (tiles[i].rotatable) {
      rotatableIndices.push(i);
    }
  }
  
  let solved = false;
  let solution = null;
  
  function search(idx) {
    if (solved) return;
    if (idx === rotatableIndices.length) {
      if (evaluateCircuit(level, currentRotations)) {
        solved = true;
        solution = [...currentRotations];
      }
      return;
    }
    const tileIdx = rotatableIndices[idx];
    for (let r = 0; r < 4; r++) {
      currentRotations[tileIdx] = r;
      search(idx + 1);
      if (solved) return;
    }
  }
  
  search(0);
  return { solved, solution };
}

// Fixed Level 13:
const l13 = {
  level: 13, rows: 3, cols: 3, title: "Level 13: Circuit Lab",
  tiles: [
    { type: TileType.SOLAR, channel: Channel.ORANGE, rot: 1, rotatable: false },
    { type: TileType.RESISTOR, rot: 1, rotatable: true },
    { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },

    { type: TileType.WIRE_CORNER, rot: 1, rotatable: true },
    { type: TileType.HEATER, channel: Channel.ORANGE, rot: 0, rotatable: false },
    { type: TileType.WIRE_TEE, rot: 3, rotatable: true }, // Connects Up, Down, Left!

    { type: TileType.WIRE_CORNER, rot: 2, rotatable: true },
    { type: TileType.RESISTOR, rot: 1, rotatable: true },
    { type: TileType.BULB, channel: Channel.ORANGE, rot: 0, rotatable: false }
  ]
};
console.log('Level 13 Fixed Test:', solveLevel(l13).solved ? 'SOLVABLE!' : 'FAIL');

// Fixed Level 9 (4x4):
// Let's create a clean 4x4 circuit with Cyan and Yellow paths that don't cross illegally
const l9 = {
  level: 9, rows: 4, cols: 4, title: "Level 9: Grid Matrix",
  tiles: [
    // Row 0: Cyan Battery -> Straight -> Corner -> Bulb (Cyan)
    { type: TileType.BATTERY, channel: Channel.CYAN, rot: 1, rotatable: false }, // Right
    { type: TileType.WIRE_STRAIGHT, rot: 1, rotatable: true },
    { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },
    { type: TileType.EMPTY, rot: 0, rotatable: false },

    // Row 1: Empty -> Empty -> Wire Straight -> Cyan Bulb
    { type: TileType.EMPTY, rot: 0, rotatable: false },
    { type: TileType.EMPTY, rot: 0, rotatable: false },
    { type: TileType.WIRE_CORNER, rot: 2, rotatable: true },
    { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false },

    // Row 2: Yellow Battery -> Wire Straight -> Wire Corner -> Empty
    { type: TileType.BATTERY, channel: Channel.YELLOW, rot: 1, rotatable: false },
    { type: TileType.RESISTOR, rot: 1, rotatable: true },
    { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },
    { type: TileType.EMPTY, rot: 0, rotatable: false },

    // Row 3: Empty -> Empty -> Wire Corner -> Yellow Bulb
    { type: TileType.EMPTY, rot: 0, rotatable: false },
    { type: TileType.EMPTY, rot: 0, rotatable: false },
    { type: TileType.WIRE_CORNER, rot: 2, rotatable: true },
    { type: TileType.BULB, channel: Channel.YELLOW, rot: 0, rotatable: false }
  ]
};
console.log('Level 9 Fixed Test:', solveLevel(l9).solved ? 'SOLVABLE!' : 'FAIL');

// Fixed Level 10 (4x4 Master Challenge):
const l10 = {
  level: 10, rows: 4, cols: 4, title: "Level 10: Quad Matrix",
  tiles: [
    // Row 0: Solar (Green) -> Resistor -> Corner -> Fan (Green)
    { type: TileType.SOLAR, channel: Channel.GREEN, rot: 1, rotatable: false },
    { type: TileType.RESISTOR, rot: 1, rotatable: true },
    { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },
    { type: TileType.FAN, channel: Channel.GREEN, rot: 0, rotatable: false },

    // Row 1: Corner -> Tesla Coil (Cyan) -> Corner -> Straight
    { type: TileType.WIRE_CORNER, rot: 1, rotatable: true },
    { type: TileType.TESLA_COIL, channel: Channel.CYAN, rot: 0, rotatable: false },
    { type: TileType.WIRE_CORNER, rot: 2, rotatable: true },
    { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },

    // Row 2: Battery (Cyan) -> Wire TEE -> Wire Straight -> Corner
    { type: TileType.BATTERY, channel: Channel.CYAN, rot: 1, rotatable: false },
    { type: TileType.WIRE_TEE, rot: 0, rotatable: true },
    { type: TileType.WIRE_STRAIGHT, rot: 1, rotatable: true },
    { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },

    // Row 3: Empty -> Cyan Bulb -> Empty -> Vacuum Tube (Green)
    { type: TileType.EMPTY, rot: 0, rotatable: false },
    { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false },
    { type: TileType.EMPTY, rot: 0, rotatable: false },
    { type: TileType.VACUUM_TUBE, channel: Channel.GREEN, rot: 0, rotatable: false }
  ]
};
console.log('Level 10 Fixed Test:', solveLevel(l10).solved ? 'SOLVABLE!' : 'FAIL');
