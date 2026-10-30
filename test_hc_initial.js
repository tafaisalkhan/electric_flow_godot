const fs = require('fs');

const TileType = {
  EMPTY: 0, WIRE_STRAIGHT: 1, WIRE_CORNER: 2, WIRE_TEE: 3, WIRE_CROSS: 4,
  BATTERY: 5, BULB: 6, SOLAR: 7, RESISTOR: 8, HEATER: 9,
  CAPACITOR: 10, FAN: 11, VACUUM_TUBE: 12, TESLA_COIL: 13
};
const Channel = { NONE: 0, CYAN: 1, YELLOW: 2, ORANGE: 3, MAGENTA: 4, GREEN: 5 };
const DIR_UP = 1, DIR_RIGHT = 2, DIR_DOWN = 4, DIR_LEFT = 8, DIR_ALL = 15;

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
  
  const targets = [];
  for (let i = 0; i < tiles.length; i++) {
    if ([TileType.BULB, TileType.HEATER, TileType.FAN, TileType.VACUUM_TUBE, TileType.TESLA_COIL].includes(tiles[i].type)) {
      targets.push(i);
    }
  }
  
  if (targets.length === 0) return false;
  return targets.every(idx => powered[idx]);
}

const gdContent = fs.readFileSync('scripts/electric_levels.gd', 'utf8');

console.log('=== CHECKING HANDCRAFTED LEVELS 1 TO 16 ===');
for (let num = 1; num <= 16; num++) {
  const start = gdContent.indexOf('static func _level_' + num + '()');
  const end = gdContent.indexOf('static func _level_' + (num + 1) + '()');
  const block = gdContent.slice(start, end !== -1 ? end : start + 1500);
  
  const rowsM = block.match(/\"rows\":\s*(\d+)/);
  const colsM = block.match(/\"cols\":\s*(\d+)/);
  const rows = rowsM ? parseInt(rowsM[1]) : 3;
  const cols = colsM ? parseInt(colsM[1]) : 3;
  
  const tilesBlockStart = block.indexOf('\"tiles\": [');
  const tilesBlockEnd = block.indexOf(']', tilesBlockStart);
  const tilesStr = block.slice(tilesBlockStart, tilesBlockEnd + 1);
  
  const tileMatches = [...tilesStr.matchAll(/\{([^{}]+)\}/g)];
  const tiles = [];
  for (const tm of tileMatches) {
    const tBody = tm[1];
    let type = 0;
    if (tBody.includes('WIRE_STRAIGHT')) type = 1;
    else if (tBody.includes('WIRE_CORNER')) type = 2;
    else if (tBody.includes('WIRE_TEE')) type = 3;
    else if (tBody.includes('WIRE_CROSS')) type = 4;
    else if (tBody.includes('BATTERY')) type = 5;
    else if (tBody.includes('BULB')) type = 6;
    else if (tBody.includes('SOLAR')) type = 7;
    else if (tBody.includes('RESISTOR')) type = 8;
    else if (tBody.includes('HEATER')) type = 9;
    else if (tBody.includes('CAPACITOR')) type = 10;
    else if (tBody.includes('FAN')) type = 11;
    else if (tBody.includes('VACUUM_TUBE')) type = 12;
    else if (tBody.includes('TESLA_COIL')) type = 13;
    
    let ch = 0;
    if (tBody.includes('CYAN')) ch = 1;
    else if (tBody.includes('YELLOW')) ch = 2;
    else if (tBody.includes('ORANGE')) ch = 3;
    else if (tBody.includes('MAGENTA')) ch = 4;
    else if (tBody.includes('GREEN')) ch = 5;
    
    const rotM = tBody.match(/\"rot\":\s*(\d+)/);
    const rot = rotM ? parseInt(rotM[1]) : 0;
    
    const rotatable = tBody.includes('\"rotatable\": true');
    
    let ports = 0;
    const portsM = tBody.match(/\"ports\":\s*([^,\n}]+)/);
    if (portsM) {
      const pStr = portsM[1];
      if (pStr.includes('DIR_UP')) ports |= 1;
      if (pStr.includes('DIR_RIGHT')) ports |= 2;
      if (pStr.includes('DIR_DOWN')) ports |= 4;
      if (pStr.includes('DIR_LEFT')) ports |= 8;
    }
    
    tiles.push({ type, channel: ch, rot, rotatable, ports });
  }
  
  const levelObj = { rows, cols, tiles };
  const initSolved = evaluateCircuit(levelObj, tiles.map(t => t.rot));
  console.log('Level ' + num + ' (' + rows + 'x' + cols + '): initial solved = ' + initSolved);
}
