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

// Read electric_levels.gd
const content = fs.readFileSync('scripts/electric_levels.gd', 'utf8');

// Parse level dictionaries
// We can extract level blocks
function parseLevels(text) {
  const levels = [];
  const regex = /static func _level_(\d+)\(\) -> Dictionary:[\s\S]*?return \{([\s\S]*?)\n\t\}/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    const lvlNum = parseInt(match[1]);
    const body = match[2];
    
    // Extract rows, cols
    const rowsMatch = body.match(/"rows":\s*(\d+)/);
    const colsMatch = body.match(/"cols":\s*(\d+)/);
    const rows = rowsMatch ? parseInt(rowsMatch[1]) : 3;
    const cols = colsMatch ? parseInt(colsMatch[1]) : 3;
    
    // Extract tiles array
    const tilesMatch = body.match(/"tiles":\s*\[([\s\S]*?)\]/);
    if (!tilesMatch) continue;
    
    const tileStrs = tilesMatch[1].split(/\},\s*\{|\{[\s\S]*?\}/g);
    // Better: parse JSON-like objects
    const tiles = [];
    const tRegex = /\{([^}]+)\}/g;
    let tMatch;
    while ((tMatch = tRegex.exec(tilesMatch[1])) !== null) {
      const tText = tMatch[1];
      const t = {};
      
      // type
      const typeM = tText.match(/"type":\s*ElectricEnums\.TileType\.([A-Z_]+)/);
      t.type = typeM ? TileType[typeM[1]] : TileType.EMPTY;
      
      // channel
      const chM = tText.match(/"channel":\s*ElectricEnums\.Channel\.([A-Z_]+)/);
      t.channel = chM ? Channel[chM[1]] : Channel.NONE;
      
      // rot
      const rotM = tText.match(/"rot":\s*(\d+)/);
      t.rot = rotM ? parseInt(rotM[1]) : 0;
      
      // rotatable
      const rotatableM = tText.match(/"rotatable":\s*(true|false)/);
      t.rotatable = rotatableM ? rotatableM[1] === 'true' : (t.type !== TileType.EMPTY);
      
      // custom ports
      if (tText.includes('"ports":')) {
        let pVal = 0;
        if (tText.includes('DIR_UP')) pVal |= DIR_UP;
        if (tText.includes('DIR_RIGHT')) pVal |= DIR_RIGHT;
        if (tText.includes('DIR_DOWN')) pVal |= DIR_DOWN;
        if (tText.includes('DIR_LEFT')) pVal |= DIR_LEFT;
        t.ports = pVal;
      }
      
      tiles.push(t);
    }
    
    levels.push({ level: lvlNum, rows, cols, tiles });
  }
  return levels;
}

const levels = parseLevels(content);
console.log(`Parsed ${levels.length} levels.`);

function isTarget(type) {
  return [TileType.BULB, TileType.HEATER, TileType.FAN, TileType.VACUUM_TUBE, TileType.TESLA_COIL].includes(type);
}

function isSource(type) {
  return type === TileType.BATTERY || type === TileType.SOLAR;
}

function evaluateCircuit(level, tileRotations) {
  const { rows, cols, tiles } = level;
  
  // Power state for each tile
  const isPowered = new Array(tiles.length).fill(false);
  
  // Multi-source BFS
  const queue = [];
  const visited = {}; // `${r},${c}` -> Set of channels
  
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const idx = r * cols + c;
      const t = tiles[idx];
      if (isSource(t.type)) {
        queue.push({ r, c, ch: t.channel });
        const key = `${r},${c}`;
        visited[key] = new Set([t.channel]);
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
            // Wire, Resistor, Capacitor
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
  
  // Check victory
  for (let i = 0; i < tiles.length; i++) {
    if (isTarget(tiles[i].type)) {
      if (!isPowered[i]) return false;
    }
  }
  return true;
}

// Solve level using DFS on rotatable tiles
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

console.log("\n--- LEVEL SOLVABILITY REPORT ---");
for (const lvl of levels) {
  const result = solveLevel(lvl);
  if (result.solved) {
    console.log(`Level ${lvl.level} (${lvl.rows}x${lvl.cols}): SOLVABLE!`);
  } else {
    console.log(`Level ${lvl.level} (${lvl.rows}x${lvl.cols}): *** UNSOLVABLE ***`);
  }
}
