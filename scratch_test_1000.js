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

// Pseudo-Random Number Generator (Linear Congruential Generator)
class DeterministicRNG {
  constructor(seed) {
    this.state = seed % 2147483647;
    if (this.state <= 0) this.state += 2147483646;
  }
  next() {
    this.state = (this.state * 16807) % 2147483647;
    return (this.state - 1) / 2147483646;
  }
  randi(max) {
    return Math.floor(this.next() * max);
  }
  randRange(min, max) {
    return min + Math.floor(this.next() * (max - min + 1));
  }
}

// Procedural Guaranteed-Solvable Level Generator
function generateProceduralLevel(levelNum) {
  const rng = new DeterministicRNG(levelNum * 104729 + 7919);
  
  let rows = 3;
  let cols = 3;
  if (levelNum > 300) {
    rows = 4;
    cols = 4;
  } else if (levelNum > 100) {
    rows = (rng.randi(2) === 0) ? 3 : 4;
    cols = rows;
  }
  
  const totalTiles = rows * cols;
  const grid = [];
  for (let i = 0; i < totalTiles; i++) {
    grid.push({ type: TileType.EMPTY, channel: Channel.NONE, rot: 0, rotatable: false });
  }
  
  // Pick source type and channel
  const channels = [Channel.CYAN, Channel.YELLOW, Channel.ORANGE, Channel.GREEN, Channel.MAGENTA];
  const sourceChannel = channels[rng.randi(channels.length)];
  const sourceType = (rng.randi(2) === 0) ? TileType.SOLAR : TileType.BATTERY;
  
  // Place source at edge
  const sourceRow = rng.randi(rows);
  const sourceCol = 0;
  const sourceIdx = sourceRow * cols + sourceCol;
  
  // Target consumers to choose from
  const targetTypes = [
    TileType.BULB,
    TileType.FAN,
    TileType.VACUUM_TUBE,
    TileType.HEATER,
    TileType.TESLA_COIL
  ];
  
  // Carve random path from source to target
  let currR = sourceRow;
  let currC = sourceCol;
  const path = [{ r: currR, c: currC }];
  const visitedCells = new Set([`${currR},${currC}`]);
  
  const pathLen = rng.randRange(rows, rows + cols);
  const dirs = [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT];
  
  for (let step = 0; step < pathLen; step++) {
    const validMoves = [];
    for (const d of dirs) {
      const [dr, dc] = getOffset(d);
      const nr = currR + dr;
      const nc = currC + dc;
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !visitedCells.has(`${nr},${nc}`)) {
        validMoves.push({ d, nr, nc });
      }
    }
    if (validMoves.length === 0) break;
    const move = validMoves[rng.randi(validMoves.length)];
    currR = move.nr;
    currC = move.nc;
    path.push({ r: currR, c: currC });
    visitedCells.add(`${currR},${currC}`);
  }
  
  if (path.length < 3) {
    // Fallback: simple line
    path.length = 0;
    visitedCells.clear();
    for (let c = 0; c < cols; c++) {
      path.push({ r: 0, c });
    }
  }
  
  // Calculate required ports for each cell in path
  const cellRequiredPorts = {};
  for (let i = 0; i < path.length; i++) {
    const cell = path[i];
    let req = 0;
    if (i > 0) {
      const prev = path[i - 1];
      const dr = prev.r - cell.r;
      const dc = prev.c - cell.c;
      if (dr === -1) req |= DIR_UP;
      if (dr === 1) req |= DIR_DOWN;
      if (dc === -1) req |= DIR_LEFT;
      if (dc === 1) req |= DIR_RIGHT;
    }
    if (i < path.length - 1) {
      const next = path[i + 1];
      const dr = next.r - cell.r;
      const dc = next.c - cell.c;
      if (dr === -1) req |= DIR_UP;
      if (dr === 1) req |= DIR_DOWN;
      if (dc === -1) req |= DIR_LEFT;
      if (dc === 1) req |= DIR_RIGHT;
    }
    cellRequiredPorts[`${cell.r},${cell.c}`] = req;
  }
  
  // Source tile
  const startCell = path[0];
  const startIdx = startCell.r * cols + startCell.c;
  const startOutDir = cellRequiredPorts[`${startCell.r},${startCell.c}`];
  let startRot = 0;
  if (startOutDir === DIR_UP) startRot = 0;
  else if (startOutDir === DIR_RIGHT) startRot = 1;
  else if (startOutDir === DIR_DOWN) startRot = 2;
  else if (startOutDir === DIR_LEFT) startRot = 3;
  
  grid[startIdx] = {
    type: sourceType,
    channel: sourceChannel,
    rot: startRot,
    rotatable: false
  };
  
  // Target tile at end of path
  const endCell = path[path.length - 1];
  const endIdx = endCell.r * cols + endCell.c;
  const chosenTargetType = targetTypes[rng.randi(targetTypes.length)];
  grid[endIdx] = {
    type: chosenTargetType,
    channel: sourceChannel,
    rot: 0,
    rotatable: false
  };
  
  // Intermediate tiles along path
  for (let i = 1; i < path.length - 1; i++) {
    const cell = path[i];
    const idx = cell.r * cols + cell.c;
    const req = cellRequiredPorts[`${cell.r},${cell.c}`];
    
    let tileType = TileType.WIRE_STRAIGHT;
    let solvedRot = 0;
    
    // Check if straight or corner
    if (req === (DIR_UP | DIR_DOWN)) {
      tileType = (rng.randi(2) === 0) ? TileType.RESISTOR : TileType.WIRE_STRAIGHT;
      solvedRot = 0; // vertical
    } else if (req === (DIR_LEFT | DIR_RIGHT)) {
      tileType = (rng.randi(2) === 0) ? TileType.RESISTOR : TileType.WIRE_STRAIGHT;
      solvedRot = 1; // horizontal
    } else if (req === (DIR_DOWN | DIR_RIGHT)) {
      tileType = TileType.WIRE_CORNER;
      solvedRot = 0;
    } else if (req === (DIR_DOWN | DIR_LEFT)) {
      tileType = TileType.WIRE_CORNER;
      solvedRot = 1;
    } else if (req === (DIR_UP | DIR_LEFT)) {
      tileType = TileType.WIRE_CORNER;
      solvedRot = 2;
    } else if (req === (DIR_UP | DIR_RIGHT)) {
      tileType = TileType.WIRE_CORNER;
      solvedRot = 3;
    }
    
    // Scramble: rotate by 1, 2, or 3 steps
    const scramble = rng.randRange(1, 3);
    const initialRot = (solvedRot + scramble) % 4;
    
    grid[idx] = {
      type: tileType,
      rot: initialRot,
      rotatable: true
    };
  }
  
  // World theme names
  const worldNames = ["Jungle Circuit", "Ice Crystal Power", "Ocean Current", "Mountain Voltage", "Volcano Surge"];
  const worldIdx = Math.min(Math.floor((levelNum - 1) / 200), 4);
  const title = `Level ${levelNum}: ${worldNames[worldIdx]}`;
  
  return {
    level: levelNum,
    rows,
    cols,
    title,
    tiles: grid
  };
}

// Function to solve procedural level (we know solved rotations for each tile)
function verifyProceduralLevelSolvable(level) {
  // Can also test by checking if evaluating at solved state passes!
  // In our generator, every path is guaranteed connected from source to target.
  const solvedRotations = level.tiles.map(t => t.rot);
  // Test with full solver
  const res = solveLevel(level);
  return res.solved;
}

console.log("Generating and verifying 100 random procedural levels up to Level 1000...");
let allPassed = true;
let testedCount = 0;
for (let lvl = 17; lvl <= 1000; lvl += 10) {
  const pLevel = generateProceduralLevel(lvl);
  const ok = solveLevel(pLevel).solved;
  testedCount++;
  if (!ok) {
    console.error(`FAILED on Level ${lvl}!`);
    allPassed = false;
    break;
  }
}

if (allPassed) {
  console.log(`ALL ${testedCount} TESTED PROCEDURAL LEVELS UP TO 1000 ARE 100% SOLVABLE!`);
}
