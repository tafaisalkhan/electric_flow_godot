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

function getActivePorts(type, rot) {
  return rotatePorts(BASE_PORTS[type] || 0, rot);
}

// Simulate _generate_procedural_level in JS exactly matching scripts/electric_levels.gd
function generateProcedural(levelNum) {
  let seedVal = (levelNum * 7919) % 2147483647;
  if (seedVal <= 0) seedVal += 2147483646;

  const nextRand = () => {
    seedVal = (seedVal * 16807) % 2147483647;
    return (seedVal - 1) / 2147483646.0;
  };
  const randI = (maxV) => Math.floor(nextRand() * maxV);

  let rows = 3, cols = 3;
  if (levelNum > 200) { rows = 5; cols = 5; }
  else if (levelNum > 40) { rows = 4; cols = 4; }

  let circuitCount = 1;
  if (levelNum > 500) circuitCount = 3;
  else if (levelNum > 80) circuitCount = 2;

  const allChannels = [1, 2, 3, 4, 5]; // CYAN, YELLOW, ORANGE, GREEN, MAGENTA
  for (let i = allChannels.length - 1; i > 0; i--) {
    const j = randI(i + 1);
    const tmp = allChannels[i];
    allChannels[i] = allChannels[j];
    allChannels[j] = tmp;
  }

  const totalTiles = rows * cols;
  const tiles = [];
  for (let i = 0; i < totalTiles; i++) {
    tiles.push({ type: 'EMPTY', channel: 0, rot: 0, rotatable: false });
  }

  const targetTypes = ['BULB', 'FAN'];
  if (levelNum > 25) { targetTypes.push('HEATER'); targetTypes.push('VACUUM_TUBE'); }
  if (levelNum > 60) { targetTypes.push('TESLA_COIL'); }

  const occupied = new Set();
  const dirs = [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT];

  for (let cIdx = 0; cIdx < circuitCount; cIdx++) {
    const channel = allChannels[cIdx % allChannels.length];
    const sourceType = (randI(2) === 0) ? 'SOLAR' : 'BATTERY';

    const freeCells = [];
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const k = r + ',' + c;
        if (!occupied.has(k)) freeCells.push([r, c]);
      }
    }
    if (freeCells.length < 3) break;

    const startCell = freeCells[randI(freeCells.length)];
    const path = [startCell];
    occupied.add(startCell[0] + ',' + startCell[1]);

    const targetLen = Math.min(rows + cols, 3 + randI(rows + 2));
    let currCell = startCell;

    for (let step = 0; step < targetLen; step++) {
      const validMoves = [];
      for (const d of dirs) {
        const [dr, dc] = OFFSETS[d];
        const nr = currCell[0] + dr, nc = currCell[1] + dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          if (!occupied.has(nr + ',' + nc)) validMoves.push([nr, nc]);
        }
      }
      if (validMoves.length === 0) break;
      const nextPos = validMoves[randI(validMoves.length)];
      currCell = nextPos;
      path.push(currCell);
      occupied.add(currCell[0] + ',' + currCell[1]);
    }

    if (path.length < 2) continue;

    const reqPorts = {};
    for (let i = 0; i < path.length; i++) {
      const p = path[i];
      const k = p[0] + ',' + p[1];
      let pMask = 0;
      if (i > 0) {
        const prev = path[i - 1];
        const dr = prev[0] - p[0], dc = prev[1] - p[1];
        if (dr === -1) pMask |= DIR_UP;
        else if (dr === 1) pMask |= DIR_DOWN;
        else if (dc === -1) pMask |= DIR_LEFT;
        else if (dc === 1) pMask |= DIR_RIGHT;
      }
      if (i < path.length - 1) {
        const next = path[i + 1];
        const dr = next[0] - p[0], dc = next[1] - p[1];
        if (dr === -1) pMask |= DIR_UP;
        else if (dr === 1) pMask |= DIR_DOWN;
        else if (dc === -1) pMask |= DIR_LEFT;
        else if (dc === 1) pMask |= DIR_RIGHT;
      }
      reqPorts[k] = pMask;
    }

    // Source
    const sPos = path[0];
    const sIdx = sPos[0] * cols + sPos[1];
    const sOut = reqPorts[sPos[0] + ',' + sPos[1]];
    let sRot = 0;
    if (sOut === DIR_UP) sRot = 0;
    else if (sOut === DIR_RIGHT) sRot = 1;
    else if (sOut === DIR_DOWN) sRot = 2;
    else if (sOut === DIR_LEFT) sRot = 3;

    tiles[sIdx] = { type: sourceType, channel, rot: sRot, rotatable: false };

    // Target
    const ePos = path[path.length - 1];
    const eIdx = ePos[0] * cols + ePos[1];
    const chosenTarget = targetTypes[randI(targetTypes.length)];
    tiles[eIdx] = { type: chosenTarget, channel, rot: 0, rotatable: false };

    // Intermediate
    for (let i = 1; i < path.length - 1; i++) {
      const p = path[i];
      const idx = p[0] * cols + p[1];
      const req = reqPorts[p[0] + ',' + p[1]];

      let tType = 'WIRE_STRAIGHT';
      let solvedRot = 0;

      if (req === (DIR_UP | DIR_DOWN)) {
        tType = 'WIRE_STRAIGHT';
        solvedRot = 0;
      } else if (req === (DIR_LEFT | DIR_RIGHT)) {
        tType = 'WIRE_STRAIGHT';
        solvedRot = 1;
      } else if (req === (DIR_DOWN | DIR_RIGHT)) {
        tType = 'WIRE_CORNER';
        solvedRot = 0;
      } else if (req === (DIR_DOWN | DIR_LEFT)) {
        tType = 'WIRE_CORNER';
        solvedRot = 1;
      } else if (req === (DIR_UP | DIR_LEFT)) {
        tType = 'WIRE_CORNER';
        solvedRot = 2;
      } else if (req === (DIR_UP | DIR_RIGHT)) {
        tType = 'WIRE_CORNER';
        solvedRot = 3;
      }

      const delta = 1 + randI(3);
      const initialRot = (solvedRot + delta) % 4;

      tiles[idx] = { type: tType, channel: 0, rot: initialRot, rotatable: true };
    }
  }

  return { rows, cols, tiles };
}

function isSolvable(levelData) {
  const { rows, cols, tiles } = levelData;
  const rotIndices = [];
  tiles.forEach((t, i) => { if (t.rotatable) rotIndices.push(i); });

  const totalComb = Math.pow(4, rotIndices.length);
  for (let c = 0; c < totalComb; c++) {
    let temp = c;
    const testTiles = tiles.map(t => ({ ...t }));
    for (let i = 0; i < rotIndices.length; i++) {
      testTiles[rotIndices[i]].rot = temp % 4;
      temp = Math.floor(temp / 4);
    }

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

        if (nTile.channel && nTile.channel !== 0 && nTile.channel !== ch) continue;

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
    testTiles.forEach((t, idx) => {
      if (['BULB', 'FAN', 'HEATER', 'VACUUM_TUBE', 'TESLA_COIL'].includes(t.type)) {
        targets.push(idx);
      }
    });

    if (targets.length > 0 && targets.every(idx => powered.has(idx))) {
      return true;
    }
  }
  return false;
}

console.log('Testing procedural levels 17 to 50 for guaranteed solvability...');
let allPassed = true;
for (let lvl = 17; lvl <= 50; lvl++) {
  const pLvl = generateProcedural(lvl);
  const solvable = isSolvable(pLvl);
  if (!solvable) {
    console.error(`Procedural Level ${lvl} is NOT SOLVABLE!`);
    allPassed = false;
  }
}
if (allPassed) {
  console.log('ALL PROCEDURAL LEVELS TESTED (17-50) ARE 100% SOLVABLE!');
}
