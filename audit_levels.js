const fs = require('fs');

const DIR_UP = 1, DIR_RIGHT = 2, DIR_DOWN = 4, DIR_LEFT = 8;
const OPPOSITE = { [DIR_UP]: DIR_DOWN, [DIR_DOWN]: DIR_UP, [DIR_LEFT]: DIR_RIGHT, [DIR_RIGHT]: DIR_LEFT };
const OFFSETS = { [DIR_UP]: [-1, 0], [DIR_DOWN]: [1, 0], [DIR_LEFT]: [0, -1], [DIR_RIGHT]: [0, 1] };

function rotatePorts(ports, rot) {
  let res = 0;
  for (let b = 0; b < 4; b++) {
    if (ports & (1 << b)) {
      res |= (1 << ((b + rot) % 4));
    }
  }
  return res;
}

const BASE_PORTS = {
  EMPTY: 0,
  WIRE_STRAIGHT: DIR_UP | DIR_DOWN,
  WIRE_CORNER: DIR_UP | DIR_RIGHT,
  WIRE_TEE: DIR_UP | DIR_RIGHT | DIR_DOWN,
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

function getActivePorts(type, rot) {
  return rotatePorts(BASE_PORTS[type] || 0, rot);
}

const content = fs.readFileSync('scripts/electric_levels.gd', 'utf8');

for (let lvl = 1; lvl <= 16; lvl++) {
  const startPattern = `static func _level_${lvl}() -> Dictionary:`;
  const startIdx = content.indexOf(startPattern);
  if (startIdx === -1) {
    console.log(`Level ${lvl} not found`);
    continue;
  }
  
  const endIdx = content.indexOf(`\n# Level `, startIdx + 1);
  const block = content.substring(startIdx, endIdx !== -1 ? endIdx : startIdx + 2000);
  
  const rowsMatch = block.match(/"rows":\s*(\d+)/);
  const colsMatch = block.match(/"cols":\s*(\d+)/);
  const minMovesMatch = block.match(/"min_moves":\s*(\d+)/);
  
  const rows = rowsMatch ? parseInt(rowsMatch[1]) : 3;
  const cols = colsMatch ? parseInt(colsMatch[1]) : 3;
  const declaredMinMoves = minMovesMatch ? parseInt(minMovesMatch[1]) : 0;
  
  const tiles = [];
  const lines = block.split('\n');
  for (const line of lines) {
    if (!line.includes('ElectricEnums.TileType.')) continue;
    const typeMatch = line.match(/ElectricEnums\.TileType\.(\w+)/);
    if (!typeMatch) continue;
    const type = typeMatch[1];
    const rotMatch = line.match(/"rot":\s*(\d+)/);
    const rotatableMatch = line.match(/"rotatable":\s*(true|false)/);
    const channelMatch = line.match(/ElectricEnums\.Channel\.(\w+)/);
    
    tiles.push({
      type,
      rot: rotMatch ? parseInt(rotMatch[1]) : 0,
      rotatable: rotatableMatch ? rotatableMatch[1] === 'true' : false,
      channel: channelMatch ? channelMatch[1] : 'CYAN'
    });
  }
  
  const rotIndices = [];
  tiles.forEach((t, i) => { if (t.rotatable) rotIndices.push(i); });
  
  function checkSolve(testTiles) {
    const queue = [];
    const visited = new Set();
    const powered = new Set();
    
    testTiles.forEach((t, idx) => {
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
      const currPorts = getActivePorts(testTiles[idx].type, testTiles[idx].rot);
      
      for (const dir of [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT]) {
        if ((currPorts & dir) === 0) continue;
        const [dr, dc] = OFFSETS[dir];
        const nr = r + dr, nc = c + dc;
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        const nIdx = nr * cols + nc;
        const nTile = testTiles[nIdx];
        if (nTile.type === 'EMPTY') continue;
        
        const opp = OPPOSITE[dir];
        const nPorts = getActivePorts(nTile.type, nTile.rot);
        if ((nPorts & opp) === 0) continue;
        
        powered.add(nIdx);
        const key = nIdx + ':' + ch;
        if (!visited.has(key)) {
          visited.add(key);
          if (nTile.type !== 'BATTERY' && nTile.type !== 'SOLAR') {
            queue.push({ idx: nIdx, ch });
          }
        }
      }
    }
    
    const targets = [];
    testTiles.forEach((t, idx) => {
      if (['BULB', 'FAN', 'HEATER', 'VACUUM_TUBE', 'TESLA_COIL'].includes(t.type)) {
        targets.push(idx);
      }
    });
    
    const solved = targets.length > 0 && targets.every(idx => powered.has(idx));
    return { solved, poweredCount: powered.size, totalNonEmpty: testTiles.filter(t => t.type !== 'EMPTY').length };
  }
  
  let solutions = 0;
  let actualMinMoves = Infinity;
  let fullWireSolutions = 0;
  
  const totalComb = Math.pow(4, rotIndices.length);
  for (let c = 0; c < totalComb; c++) {
    let temp = c;
    const testTiles = tiles.map(t => ({ ...t }));
    let moves = 0;
    for (let i = 0; i < rotIndices.length; i++) {
      const r = temp % 4;
      temp = Math.floor(temp / 4);
      const origRot = tiles[rotIndices[i]].rot;
      testTiles[rotIndices[i]].rot = r;
      const diff = (r - origRot + 4) % 4;
      moves += diff;
    }
    
    const res = checkSolve(testTiles);
    if (res.solved) {
      solutions++;
      if (moves < actualMinMoves) actualMinMoves = moves;
      if (res.poweredCount === res.totalNonEmpty) fullWireSolutions++;
    }
  }
  
  console.log(`Lvl ${lvl} (${rows}x${cols}, tiles=${tiles.length}, rotatable=${rotIndices.length}): sol=${solutions}, fullWireSol=${fullWireSolutions}, declaredMin=${declaredMinMoves}, actualMin=${actualMinMoves}`);
}
