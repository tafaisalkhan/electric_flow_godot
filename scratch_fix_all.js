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

// Now let's design fixed versions for levels 1 to 16 and verify each one
const handcraftedLevels = [
  // Level 1: 2x2 - Solar panel -> Corner wire -> Electric Fan
  {
    level: 1, rows: 2, cols: 2, title: "Solar & Cooling Fan",
    tiles: [
      { type: TileType.SOLAR, channel: Channel.GREEN, rot: 1, rotatable: false }, // Right into (0,1)
      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true }, // Corner connects Left & Down into (1,1)
      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.FAN, channel: Channel.GREEN, rot: 0, rotatable: false } // Receives from Up
    ]
  },
  // Level 2: 2x2 - Battery -> Resistor -> Corner -> Vacuum Tube
  {
    level: 2, rows: 2, cols: 2, title: "Vacuum Tube Valve",
    tiles: [
      { type: TileType.BATTERY, channel: Channel.CYAN, rot: 1, rotatable: false }, // Right into (0,1)
      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true }, // Connects Left & Down into (1,1)
      { type: TileType.VACUUM_TUBE, channel: Channel.CYAN, rot: 0, rotatable: false }, // At (1,0), receives from Right
      { type: TileType.WIRE_CORNER, rot: 1, rotatable: true } // At (1,1), connects Up & Left into (1,0)
    ]
  },
  // Level 3: 3x3 - Solar -> Resistor -> Corner -> Straight -> Heater
  {
    level: 3, rows: 3, cols: 3, title: "Heating Element",
    tiles: [
      { type: TileType.SOLAR, channel: Channel.YELLOW, rot: 1, rotatable: false },
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.WIRE_CORNER, rot: 2, rotatable: true },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.WIRE_STRAIGHT, rot: 1, rotatable: true },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.HEATER, channel: Channel.YELLOW, rot: 0, rotatable: false }
    ]
  },
  // Level 4: 3x3 - Tesla Arc & Fan
  {
    level: 4, rows: 3, cols: 3, title: "Tesla Arc",
    tiles: [
      { type: TileType.TESLA_COIL, channel: Channel.CYAN, rot: 0, rotatable: false },
      { type: TileType.WIRE_TEE, rot: 0, rotatable: true },
      { type: TileType.FAN, channel: Channel.CYAN, rot: 0, rotatable: false },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.WIRE_STRAIGHT, rot: 1, rotatable: true },
      { type: TileType.EMPTY, rot: 0, rotatable: false },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.BATTERY, channel: Channel.CYAN, rot: 0, rotatable: false },
      { type: TileType.EMPTY, rot: 0, rotatable: false }
    ]
  },
  // Level 5: 3x3 - Dual Grid
  {
    level: 5, rows: 3, cols: 3, title: "Dual Grid",
    tiles: [
      { type: TileType.SOLAR, channel: Channel.YELLOW, rot: 1, rotatable: false },
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.FAN, channel: Channel.YELLOW, rot: 0, rotatable: false },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.EMPTY, rot: 0, rotatable: false },

      { type: TileType.BATTERY, channel: Channel.CYAN, rot: 1, rotatable: false },
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.VACUUM_TUBE, channel: Channel.CYAN, rot: 0, rotatable: false }
    ]
  },
  // Level 6: 3x3 - Multiple junctions
  {
    level: 6, rows: 3, cols: 3, title: "Level 6",
    tiles: [
      { type: TileType.BATTERY, channel: Channel.CYAN, rot: 1, rotatable: false },
      { type: TileType.WIRE_CORNER, rot: 1, rotatable: true },
      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },

      { type: TileType.WIRE_CORNER, rot: 2, rotatable: true },
      { type: TileType.WIRE_TEE, rot: 1, rotatable: true },
      { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false },

      { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },
      { type: TileType.EMPTY, rot: 0, rotatable: false }
    ]
  },
  // Level 7: 3x3 - Circuit puzzle
  {
    level: 7, rows: 3, cols: 3, title: "Level 7",
    tiles: [
      { type: TileType.WIRE_CORNER, rot: 1, rotatable: true },
      { type: TileType.WIRE_TEE, rot: 2, rotatable: true },
      { type: TileType.BATTERY, channel: Channel.YELLOW, rot: 3, rotatable: false },

      { type: TileType.WIRE_STRAIGHT, rot: 1, rotatable: true },
      { type: TileType.BULB, channel: Channel.YELLOW, rot: 0, rotatable: false },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },

      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },
      { type: TileType.BULB, channel: Channel.YELLOW, rot: 0, rotatable: false },
      { type: TileType.WIRE_CORNER, rot: 3, rotatable: true }
    ]
  },
  // Level 8: 3x3 - Video level fixed!
  // To make Level 8 solvable:
  // Yellow Battery at (0, 2) pointing LEFT (rot 3) into (0, 1) Yellow Bulb.
  // Cyan Battery at (2, 2) has ports: DIR_UP | DIR_LEFT (or rotatable: false).
  // Notice in the original video, battery at (2, 2) connects to BOTH Up and Left!
  // Setting "ports": DIR_UP | DIR_LEFT for (2, 2) makes it feed both branches!
  {
    level: 8, rows: 3, cols: 3, title: "Level 8",
    tiles: [
      { type: TileType.VACUUM_TUBE, channel: Channel.CYAN, rot: 0, ports: DIR_DOWN | DIR_RIGHT, rotatable: false },
      { type: TileType.BULB, channel: Channel.YELLOW, rot: 0, ports: DIR_LEFT | DIR_RIGHT | DIR_DOWN, rotatable: true },
      { type: TileType.BATTERY, channel: Channel.YELLOW, rot: 3, rotatable: false },

      { type: TileType.WIRE_TEE, rot: 2, rotatable: true },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },
      { type: TileType.BULB, channel: Channel.CYAN, rot: 0, ports: DIR_DOWN | DIR_LEFT | DIR_UP, rotatable: false },

      { type: TileType.WIRE_CORNER, rot: 3, rotatable: true },
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.BATTERY, channel: Channel.CYAN, rot: 0, ports: DIR_UP | DIR_LEFT, rotatable: false }
    ]
  },
  // Level 9: 4x4
  {
    level: 9, rows: 4, cols: 4, title: "Level 9",
    tiles: [
      { type: TileType.BATTERY, channel: Channel.CYAN, rot: 1, rotatable: false },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },
      { type: TileType.WIRE_TEE, rot: 0, rotatable: true },
      { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.WIRE_CORNER, rot: 1, rotatable: true },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },
      { type: TileType.EMPTY, rot: 0, rotatable: false },

      { type: TileType.BATTERY, channel: Channel.YELLOW, rot: 1, rotatable: false },
      { type: TileType.WIRE_CROSS, rot: 0, rotatable: true },
      { type: TileType.WIRE_CORNER, rot: 2, rotatable: true },
      { type: TileType.BULB, channel: Channel.YELLOW, rot: 0, rotatable: false },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.WIRE_CORNER, rot: 3, rotatable: true },
      { type: TileType.WIRE_STRAIGHT, rot: 1, rotatable: true },
      { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false }
    ]
  },
  // Level 10: 4x4
  {
    level: 10, rows: 4, cols: 4, title: "Level 10",
    tiles: [
      { type: TileType.BULB, channel: Channel.YELLOW, rot: 0, rotatable: false },
      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },
      { type: TileType.WIRE_TEE, rot: 1, rotatable: true },
      { type: TileType.BATTERY, channel: Channel.YELLOW, rot: 2, rotatable: false },

      { type: TileType.WIRE_STRAIGHT, rot: 1, rotatable: true },
      { type: TileType.WIRE_CROSS, rot: 0, rotatable: true },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },
      { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false },

      { type: TileType.WIRE_TEE, rot: 3, rotatable: true },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },
      { type: TileType.WIRE_CORNER, rot: 2, rotatable: true },
      { type: TileType.WIRE_CORNER, rot: 1, rotatable: true },

      { type: TileType.BATTERY, channel: Channel.CYAN, rot: 0, rotatable: false },
      { type: TileType.BULB, channel: Channel.YELLOW, rot: 0, rotatable: false },
      { type: TileType.WIRE_STRAIGHT, rot: 1, rotatable: true },
      { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false }
    ]
  },
  // Level 11: 3x3 - Solar Flow
  {
    level: 11, rows: 3, cols: 3, title: "Level 11: Solar Flow",
    tiles: [
      { type: TileType.SOLAR, channel: Channel.GREEN, rot: 1, rotatable: false },
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.HEATER, channel: Channel.GREEN, rot: 0, rotatable: false },
      { type: TileType.WIRE_TEE, rot: 0, rotatable: true },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },
      { type: TileType.BULB, channel: Channel.GREEN, rot: 0, rotatable: false }
    ]
  },
  // Level 12: 3x3 - Hybrid Power
  {
    level: 12, rows: 3, cols: 3, title: "Level 12: Hybrid Power",
    tiles: [
      { type: TileType.SOLAR, channel: Channel.YELLOW, rot: 1, rotatable: false },
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.HEATER, channel: Channel.YELLOW, rot: 0, rotatable: false },

      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },
      { type: TileType.WIRE_CROSS, rot: 0, rotatable: true },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },

      { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false },
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.BATTERY, channel: Channel.CYAN, rot: 3, rotatable: false }
    ]
  },
  // Level 13: 3x3 - Circuit Lab
  // (0,0) Solar -> (0,1) Resistor -> (0,2) Corner
  // (1,0) Corner -> (1,1) Heater -> (1,2) Straight
  // (2,0) Straight -> (2,1) Resistor -> (2,2) Bulb
  {
    level: 13, rows: 3, cols: 3, title: "Level 13: Circuit Lab",
    tiles: [
      { type: TileType.SOLAR, channel: Channel.ORANGE, rot: 1, rotatable: false },
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },

      { type: TileType.WIRE_CORNER, rot: 1, rotatable: true },
      { type: TileType.HEATER, channel: Channel.ORANGE, rot: 0, rotatable: false },
      { type: TileType.WIRE_STRAIGHT, rot: 0, rotatable: true },

      { type: TileType.WIRE_CORNER, rot: 2, rotatable: true },
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.BULB, channel: Channel.ORANGE, rot: 0, rotatable: false }
    ]
  },
  // Level 14: 3x3 - Cooling System
  // (0,0) Solar (rot 1) -> (0,1) Resistor -> (0,2) Corner (rot 0)
  // (1,0) Wire Corner (rot 1) -> (1,1) Fan (accepts from Left/Right) -> (1,2) Corner (rot 2)
  // (2,0) Empty -> (2,1) Wire Straight -> (2,2) Bulb
  {
    level: 14, rows: 3, cols: 3, title: "Level 14: Cooling System",
    tiles: [
      { type: TileType.SOLAR, channel: Channel.CYAN, rot: 1, rotatable: false }, // Right into (0,1)
      { type: TileType.RESISTOR, rot: 1, rotatable: true }, // Left-Right
      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true }, // Connects Left & Down into (1,2)

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.FAN, channel: Channel.CYAN, rot: 0, rotatable: false }, // Center Fan
      { type: TileType.WIRE_TEE, rot: 1, rotatable: true }, // Connects Up, Down, Left into Fan!

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.BULB, channel: Channel.CYAN, rot: 0, rotatable: false } // Powered from Up (1,2)
    ]
  },
  // Level 15: 3x3 - Vacuum Valve
  {
    level: 15, rows: 3, cols: 3, title: "Level 15: Vacuum Valve",
    tiles: [
      { type: TileType.BATTERY, channel: Channel.YELLOW, rot: 1, rotatable: false }, // Right into (0,1)
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true }, // Connects Left & Down into (1,2)

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.VACUUM_TUBE, channel: Channel.YELLOW, rot: 0, rotatable: false },
      { type: TileType.WIRE_TEE, rot: 1, rotatable: true }, // Connects Up, Down, Left into Tube!

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.BULB, channel: Channel.YELLOW, rot: 0, rotatable: false }
    ]
  },
  // Level 16: 3x3 - Tesla Arc
  {
    level: 16, rows: 3, cols: 3, title: "Level 16: Tesla Arc",
    tiles: [
      { type: TileType.SOLAR, channel: Channel.MAGENTA, rot: 1, rotatable: false }, // Right into (0,1)
      { type: TileType.RESISTOR, rot: 1, rotatable: true },
      { type: TileType.WIRE_CORNER, rot: 0, rotatable: true },

      { type: TileType.FAN, channel: Channel.MAGENTA, rot: 0, rotatable: false },
      { type: TileType.TESLA_COIL, channel: Channel.MAGENTA, rot: 0, rotatable: false },
      { type: TileType.WIRE_TEE, rot: 1, rotatable: true },

      { type: TileType.EMPTY, rot: 0, rotatable: false },
      { type: TileType.VACUUM_TUBE, channel: Channel.MAGENTA, rot: 0, rotatable: false },
      { type: TileType.BULB, channel: Channel.MAGENTA, rot: 0, rotatable: false }
    ]
  }
];

console.log("Checking updated handcrafted levels:");
for (const lvl of handcraftedLevels) {
  const res = solveLevel(lvl);
  console.log(`Level ${lvl.level}: ${res.solved ? 'SOLVABLE!' : 'UNSOLVABLE'}`);
  if (!res.solved) {
    console.log("Tiles:", JSON.stringify(lvl.tiles));
  }
}
