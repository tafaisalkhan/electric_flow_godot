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

function getOppositeDir(dir) {
  switch (dir) {
    case DIR_UP: return DIR_DOWN;
    case DIR_RIGHT: return DIR_LEFT;
    case DIR_DOWN: return DIR_UP;
    case DIR_LEFT: return DIR_RIGHT;
    default: return 0;
  }
}

function getDirOffset(dir) {
  switch (dir) {
    case DIR_UP: return [-1, 0];
    case DIR_RIGHT: return [0, 1];
    case DIR_DOWN: return [1, 0];
    case DIR_LEFT: return [0, -1];
    default: return [0, 0];
  }
}

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
}

function evaluateCircuit(level, tileRotations) {
  const rows = level.rows;
  const cols = level.cols;
  const tiles = level.tiles;
  
  function getConnectedPorts(idx) {
    const tile = tiles[idx];
    if (tile.type === TileType.EMPTY) return 0;
    const base = tile.ports !== undefined && tile.ports !== 0 ? tile.ports : getBasePorts(tile.type);
    const rot = tileRotations[idx];
    return rotateMask(base, rot);
  }
  
  const powered = new Array(tiles.length).fill(false);
  const queue = [];
  const visited = new Map();
  
  for (let i = 0; i < tiles.length; i++) {
    const t = tiles[i];
    if (t.type === TileType.BATTERY || t.type === TileType.SOLAR) {
      powered[i] = true;
      queue.push({ idx: i, channel: t.channel });
      visited.set(i + ':' + t.channel, true);
    }
  }
  
  const dirs = [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT];
  
  while (queue.length > 0) {
    const curr = queue.shift();
    const currIdx = curr.idx;
    const currCh = curr.channel;
    const currR = Math.floor(currIdx / cols);
    const currC = currIdx % cols;
    const currPorts = getConnectedPorts(currIdx);
    
    for (const d of dirs) {
      if ((currPorts & d) === 0) continue;
      const [dr, dc] = getDirOffset(d);
      const nr = currR + dr;
      const nc = currC + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      
      const nIdx = nr * cols + nc;
      const nTile = tiles[nIdx];
      if (nTile.type === TileType.EMPTY) continue;
      
      const oppD = getOppositeDir(d);
      const nPorts = getConnectedPorts(nIdx);
      if ((nPorts & oppD) === 0) continue;
      
      const isTarget = [TileType.BULB, TileType.HEATER, TileType.FAN, TileType.VACUUM_TUBE, TileType.TESLA_COIL].includes(nTile.type);
      if (isTarget) {
        if (nTile.channel === Channel.NONE || nTile.channel === currCh) {
          powered[nIdx] = true;
          const key = nIdx + ':' + currCh;
          if (!visited.has(key)) {
            visited.set(key, true);
            queue.push({ idx: nIdx, channel: currCh });
          }
        }
      } else if (nTile.type !== TileType.BATTERY && nTile.type !== TileType.SOLAR) {
        powered[nIdx] = true;
        const key = nIdx + ':' + currCh;
        if (!visited.has(key)) {
          visited.set(key, true);
          queue.push({ idx: nIdx, channel: currCh });
        }
      }
    }
  }
  
  // Check victory
  const targets = [];
  for (let i = 0; i < tiles.length; i++) {
    if ([TileType.BULB, TileType.HEATER, TileType.FAN, TileType.VACUUM_TUBE, TileType.TESLA_COIL].includes(tiles[i].type)) {
      targets.push(i);
    }
  }
  
  if (targets.length === 0) return false;
  return targets.every(idx => powered[idx]);
}

// Generate level with progressive item count and guaranteed scrambled start
function generateProgressiveLevel(levelNum) {
  const rng = new DeterministicRNG(levelNum * 104729 + 7919);
  
  // Grid scaling
  let rows = 3;
  let cols = 3;
  if (levelNum > 200) {
    rows = 5;
    cols = 5;
  } else if (levelNum > 40) {
    rows = 4;
    cols = 4;
  }
  
  // Circuit count scaling
  let circuitCount = 1;
  if (levelNum > 500) {
    circuitCount = 3;
  } else if (levelNum > 80) {
    circuitCount = 2;
  }
  
  const allChannels = [Channel.CYAN, Channel.YELLOW, Channel.ORANGE, Channel.GREEN, Channel.MAGENTA];
  // Shuffle channels deterministically
  for (let i = allChannels.length - 1; i > 0; i--) {
    const j = rng.randi(i + 1);
    const temp = allChannels[i];
    allChannels[i] = allChannels[j];
    allChannels[j] = temp;
  }
  
  const totalTiles = rows * cols;
  const grid = new Array(totalTiles).fill(null).map(() => ({
    type: TileType.EMPTY,
    channel: Channel.NONE,
    rot: 0,
    rotatable: false
  }));
  
  const targetTypes = [
    TileType.BULB,
    TileType.FAN,
    TileType.VACUUM_TUBE,
    TileType.HEATER,
    TileType.TESLA_COIL
  ];
  
  const intermediateTypes = [
    TileType.RESISTOR,
    TileType.CAPACITOR
  ];
  
  const occupied = new Set();
  const solvedRotations = new Array(totalTiles).fill(0);
  
  for (let cIdx = 0; cIdx < circuitCount; cIdx++) {
    const channel = allChannels[cIdx % allChannels.length];
    const sourceType = (rng.randi(2) === 0) ? TileType.SOLAR : TileType.BATTERY;
    
    // Find unvisited starting cell
    const freeCells = [];
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const idx = r * cols + c;
        if (!occupied.has(idx)) freeCells.push([r, c]);
      }
    }
    if (freeCells.length < 3) break;
    
    const startCell = freeCells[rng.randi(freeCells.length)];
    const path = [startCell];
    const pathSet = new Set([startCell[0] + ',' + startCell[1]]);
    occupied.add(startCell[0] * cols + startCell[1]);
    
    // Path length based on grid size
    const targetLength = Math.min(rows + cols, 3 + rng.randi(rows + 2));
    let curr = startCell;
    const dirs = [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT];
    
    for (let step = 0; step < targetLength; step++) {
      const validMoves = [];
      for (const d of dirs) {
        const [dr, dc] = getDirOffset(d);
        const nr = curr[0] + dr;
        const nc = curr[1] + dc;
        const nIdx = nr * cols + nc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !occupied.has(nIdx)) {
          validMoves.push([nr, nc]);
        }
      }
      if (validMoves.length === 0) break;
      const nextCell = validMoves[rng.randi(validMoves.length)];
      curr = nextCell;
      path.push(curr);
      occupied.add(curr[0] * cols + curr[1]);
    }
    
    if (levelNum === 312) {
      console.log('Level 312 circuit', cIdx, 'path:', JSON.stringify(path));
    }
    if (path.length < 3) {
      for (const p of path) {
        occupied.delete(p[0] * cols + p[1]);
      }
      continue;
    }
    
    // Determine required ports for path
    const reqPorts = {};
    for (let i = 0; i < path.length; i++) {
      const p = path[i];
      let req = 0;
      if (i > 0) {
        const prev = path[i - 1];
        const dr = prev[0] - p[0];
        const dc = prev[1] - p[1];
        if (dr === -1) req |= DIR_UP;
        else if (dr === 1) req |= DIR_DOWN;
        else if (dc === -1) req |= DIR_LEFT;
        else if (dc === 1) req |= DIR_RIGHT;
      }
      if (i < path.length - 1) {
        const next = path[i + 1];
        const dr = next[0] - p[0];
        const dc = next[1] - p[1];
        if (dr === -1) req |= DIR_UP;
        else if (dr === 1) req |= DIR_DOWN;
        else if (dc === -1) req |= DIR_LEFT;
        else if (dc === 1) req |= DIR_RIGHT;
      }
      reqPorts[p[0] + ',' + p[1]] = req;
    }
    
    // Place Source at path[0]
    const sPos = path[0];
    const sIdx = sPos[0] * cols + sPos[1];
    const sOut = reqPorts[sPos[0] + ',' + sPos[1]];
    let sRot = 0;
    if (sOut === DIR_UP) sRot = 0;
    else if (sOut === DIR_RIGHT) sRot = 1;
    else if (sOut === DIR_DOWN) sRot = 2;
    else if (sOut === DIR_LEFT) sRot = 3;
    
    grid[sIdx] = {
      type: sourceType,
      channel: channel,
      rot: sRot,
      rotatable: false
    };
    solvedRotations[sIdx] = sRot;
    
    // Place Target at path[path.length - 1]
    const ePos = path[path.length - 1];
    const eIdx = ePos[0] * cols + ePos[1];
    const chosenTarget = targetTypes[rng.randi(targetTypes.length)];
    grid[eIdx] = {
      type: chosenTarget,
      channel: channel,
      rot: 0,
      rotatable: false
    };
    solvedRotations[eIdx] = 0;
    
    // Place intermediate wires / components along path
    for (let i = 1; i < path.length - 1; i++) {
      const p = path[i];
      const idx = p[0] * cols + p[1];
      const req = reqPorts[p[0] + ',' + p[1]];
      
      let tType = TileType.WIRE_STRAIGHT;
      let solvedRot = 0;
      
      if (req === (DIR_UP | DIR_DOWN)) {
        // Can be straight wire or resistor or capacitor!
        const pick = rng.randi(3);
        if (pick === 0) tType = TileType.RESISTOR;
        else if (pick === 1 && levelNum > 50) tType = TileType.CAPACITOR;
        else tType = TileType.WIRE_STRAIGHT;
        solvedRot = 0;
      } else if (req === (DIR_LEFT | DIR_RIGHT)) {
        const pick = rng.randi(3);
        if (pick === 0) tType = TileType.RESISTOR;
        else if (pick === 1 && levelNum > 50) tType = TileType.CAPACITOR;
        else tType = TileType.WIRE_STRAIGHT;
        solvedRot = 1;
      } else if (req === (DIR_DOWN | DIR_RIGHT)) {
        tType = TileType.WIRE_CORNER;
        solvedRot = 0;
      } else if (req === (DIR_DOWN | DIR_LEFT)) {
        tType = TileType.WIRE_CORNER;
        solvedRot = 1;
      } else if (req === (DIR_UP | DIR_LEFT)) {
        tType = TileType.WIRE_CORNER;
        solvedRot = 2;
      } else if (req === (DIR_UP | DIR_RIGHT)) {
        tType = TileType.WIRE_CORNER;
        solvedRot = 3;
      }
      
      solvedRotations[idx] = solvedRot;
      
      // GUARANTEED SCRAMBLE:
      // For straight wires/resistors/capacitors (symmetry period 2): initial must flip between 0 and 1!
      let initialRot = 0;
      if (tType === TileType.WIRE_STRAIGHT || tType === TileType.RESISTOR || tType === TileType.CAPACITOR) {
        initialRot = (solvedRot === 0) ? 1 : 0;
      } else {
        // Corner wire: rotate by 1 or 2 steps
        initialRot = (solvedRot + 1 + rng.randi(2)) % 4;
      }
      
      grid[idx] = {
        type: tType,
        channel: Channel.NONE,
        rot: initialRot,
        rotatable: true
      };
    }
  }
  
  const levelObj = {
    level: levelNum,
    rows: rows,
    cols: cols,
    title: 'Progressive Level ' + levelNum,
    tiles: grid
  };
  
  // Double-check: ensure initial state is NEVER already solved
  let scrambleAttempts = 0;
  while (evaluateCircuit(levelObj, grid.map(t => t.rot)) && scrambleAttempts < 10) {
    for (let i = 0; i < grid.length; i++) {
      if (grid[i].rotatable) {
        grid[i].rot = (grid[i].rot + 1) % 4;
      }
    }
    scrambleAttempts++;
  }
  
  // Also verify that solved state IS solved!
  const isSolvedAtGoal = evaluateCircuit(levelObj, solvedRotations);
  
  return {
    level: levelObj,
    solvedAtGoal: isSolvedAtGoal,
    solvedAtStart: evaluateCircuit(levelObj, grid.map(t => t.rot))
  };
}

const debug312 = generateProgressiveLevel(312);
console.log('DEBUG 312:');
debug312.level.tiles.forEach((t, i) => {
  if (t.type !== 0) console.log(i, 'type=' + t.type, 'rot=' + t.rot, 'rotatable=' + t.rotatable);
});
console.log('312 init solved:', evaluateCircuit(debug312.level, debug312.level.tiles.map(t => t.rot)));

console.log('Testing Progressive Generator across levels 17 to 1000...');
let failGoal = 0;
let failStart = 0;

for (let lvl = 17; lvl <= 1000; lvl++) {
  const res = generateProgressiveLevel(lvl);
  if (!res.solvedAtGoal) {
    console.error('Level ' + lvl + ' FAILED GOAL (unsolvable)!');
    failGoal++;
  }
  if (res.solvedAtStart) {
    console.error('Level ' + lvl + ' ALREADY SOLVED AT START!');
    failStart++;
  }
}

console.log('--- TEST RESULTS ---');
console.log('Failed goal (unsolvable): ' + failGoal);
console.log('Failed start (already solved): ' + failStart);
if (failGoal === 0 && failStart === 0) {
  console.log('PERFECT! ALL 984 LEVELS ARE 100% SOLVABLE AND 0% SOLVED AT START!');
}
