const fs = require('fs');

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
    return rotatePorts(tile.ports, tile.rot || 0);
  }
  const base = BASE_PORTS[tile.type] || 0;
  return rotatePorts(base, tile.rot || 0);
}

const content = fs.readFileSync('scripts/electric_levels.gd', 'utf8');

for (let lvl = 1; lvl <= 16; lvl++) {
  const match = content.match(new RegExp(`static func _level_${lvl}\\(\\)[\\s\\S]*?return\\s*({[\\s\\S]*?^\\t})`, 'm'));
  if (!match) continue;
  let raw = match[1];
  raw = raw.replace(/#.*$/gm, '')
           .replace(/ElectricEnums\.TileType\.(\w+)/g, '"$1"')
           .replace(/ElectricEnums\.Channel\.(\w+)/g, '"$1"')
           .replace(/ElectricEnums\.DIR_UP/g, '1')
           .replace(/ElectricEnums\.DIR_RIGHT/g, '2')
           .replace(/ElectricEnums\.DIR_DOWN/g, '4')
           .replace(/ElectricEnums\.DIR_LEFT/g, '8')
           .replace(/\|/g, '+')
           .replace(/,\s*([\]}])/g, '$1');

  const data = eval('(' + raw + ')');
  const { rows, cols, tiles } = data;

  const queue = [];
  const visited = new Set();
  const powered = new Set();

  tiles.forEach((t, idx) => {
    if (t.type === 'BATTERY' || t.type === 'SOLAR') {
      powered.add(idx);
      queue.push({ idx, ch: t.channel || 'CYAN' });
      visited.add(idx + ':' + (t.channel || 'CYAN'));
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

      const nCh = nTile.channel || 'NONE';
      if (nCh !== 'NONE' && nCh !== ch) continue;

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

  const litTargets = targets.filter(idx => powered.has(idx));
  const isInitiallySolved = targets.length > 0 && litTargets.length === targets.length;
  console.log(`Lvl ${lvl}: targets=${targets.length}, initiallyLit=${litTargets.length}, ALREADY_SOLVED=${isInitiallySolved}`);
}
