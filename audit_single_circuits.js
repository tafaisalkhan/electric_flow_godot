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

function solveLevel(rows, cols, tiles) {
  const rotIndices = [];
  tiles.forEach((t, i) => { if (t.rotatable) rotIndices.push(i); });

  let solutions = 0;
  let minClicks = Infinity;
  let fullCircuitSolutions = 0;

  const totalComb = Math.pow(4, rotIndices.length);
  for (let c = 0; c < totalComb; c++) {
    let temp = c;
    const testTiles = tiles.map(t => ({ ...t }));
    let clicks = 0;
    for (let i = 0; i < rotIndices.length; i++) {
      const r = temp % 4;
      temp = Math.floor(temp / 4);
      const origRot = tiles[rotIndices[i]].rot || 0;
      testTiles[rotIndices[i]].rot = r;
      const diff = (r - origRot + 4) % 4;
      clicks += diff;
    }

    const res = evaluate(rows, cols, testTiles);
    if (res.isSolved) {
      solutions++;
      if (clicks < minClicks) minClicks = clicks;
      if (res.isFullCircuit) fullCircuitSolutions++;
    }
  }

  const initialRes = evaluate(rows, cols, tiles);

  return {
    solutions,
    minClicks,
    fullCircuitSolutions,
    initiallyLit: initialRes.litCount,
    isInitiallySolved: initialRes.isSolved
  };
}

// -------------------------------------------------------------
// DEFINE ALL 16 HANDCRAFTED LEVELS (STRICTLY 1 CIRCUIT EACH!)
// -------------------------------------------------------------
const allLevels = {};

// Level 1: 2x2 Solar & Fan (GREEN)
allLevels[1] = {
  rows: 2, cols: 2, min_moves: 1, title: "Solar & Cooling Fan",
  tiles: [
    { type: 'SOLAR', channel: 'GREEN', rot: 1, rotatable: false }, // Right into (0,1)
    { type: 'WIRE_CORNER', rot: 0, rotatable: true }, // Starts rot 0 (RIGHT+DOWN). 1 click -> rot 1 (DOWN+LEFT) connects Solar to Fan!
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'FAN', channel: 'GREEN', rot: 0, rotatable: false }
  ]
};

// Level 2: 2x2 Battery & Vacuum Tube (CYAN)
allLevels[2] = {
  rows: 2, cols: 2, min_moves: 2, title: "Vacuum Tube Valve",
  tiles: [
    { type: 'BATTERY', channel: 'CYAN', rot: 1, rotatable: false }, // Right into (0,1)
    { type: 'WIRE_CORNER', rot: 0, rotatable: true }, // Starts rot 0. 1 click -> rot 1 (DOWN+LEFT)
    { type: 'VACUUM_TUBE', channel: 'CYAN', rot: 0, rotatable: false }, // (1,0)
    { type: 'WIRE_CORNER', rot: 1, rotatable: true } // Starts rot 1. 1 click -> rot 2 (UP+LEFT) into (1,0)
  ]
};

// Level 3: 3x3 Solar & Heater (YELLOW)
allLevels[3] = {
  rows: 3, cols: 3, min_moves: 1, title: "Heating Element",
  tiles: [
    { type: 'SOLAR', channel: 'YELLOW', rot: 1, rotatable: false }, // Right into (0,1)
    { type: 'RESISTOR', rot: 1, rotatable: true }, // rot 1 (LEFT+RIGHT)
    { type: 'WIRE_CORNER', rot: 0, rotatable: true }, // Starts rot 0 (RIGHT+DOWN). 1 click -> rot 1 (DOWN+LEFT)

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'WIRE_STRAIGHT', rot: 0, rotatable: true }, // rot 0 (UP+DOWN)

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'HEATER', channel: 'YELLOW', rot: 0, rotatable: false }
  ]
};

// Level 4: 3x3 Tesla Arc (CYAN)
allLevels[4] = {
  rows: 3, cols: 3, min_moves: 2, title: "Tesla Arc",
  tiles: [
    { type: 'TESLA_COIL', channel: 'CYAN', rot: 0, rotatable: false },
    { type: 'WIRE_TEE', rot: 0, rotatable: true }, // Starts rot 0 (UP+RIGHT+DOWN). Needs rot 1 (RIGHT+DOWN+LEFT) -> 1 click
    { type: 'FAN', channel: 'CYAN', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'WIRE_STRAIGHT', rot: 1, rotatable: true }, // Starts rot 1 (horizontal). 1 click -> rot 0 (vertical)
    { type: 'EMPTY', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'BATTERY', channel: 'CYAN', rot: 0, rotatable: false }, // UP into (1,1)
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 5: 3x3 Resistor Bridge (CYAN)
allLevels[5] = {
  rows: 3, cols: 3, min_moves: 1, title: "Resistor Bridge",
  tiles: [
    { type: 'BATTERY', channel: 'CYAN', rot: 1, rotatable: false },
    { type: 'RESISTOR', rot: 0, rotatable: true }, // Starts vertical. 1 click -> rot 1 (horizontal)
    { type: 'BULB', channel: 'CYAN', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 6: 3x3 Dual Branch Circuit (CYAN) - 1 Battery powers 2 Bulbs via TEE
allLevels[6] = {
  rows: 3, cols: 3, min_moves: 3, title: "Dual Branch Circuit",
  tiles: [
    { type: 'BATTERY', channel: 'CYAN', rot: 1, rotatable: false }, // Right into (0,1)
    { type: 'WIRE_TEE', rot: 0, rotatable: true },                  // 1 click -> rot 1 (RIGHT+DOWN+LEFT)
    { type: 'WIRE_CORNER', rot: 3, rotatable: true },               // Starts rot 3. 2 clicks -> rot 1 (DOWN+LEFT)

    { type: 'BULB', channel: 'CYAN', rot: 0, rotatable: false },    // Receives from (1,1)
    { type: 'WIRE_CORNER', rot: 2, rotatable: true },               // Starts rot 2. Needs rot 2 (UP+LEFT) -> wait!
    { type: 'WIRE_STRAIGHT', rot: 0, rotatable: true },             // rot 0 (UP+DOWN)

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'BULB', channel: 'CYAN', rot: 0, rotatable: false }     // Receives from (1,2)
  ]
};

// Level 7: 3x3 Dual Path Power (YELLOW) - 1 Battery powers 2 Bulbs
allLevels[7] = {
  rows: 3, cols: 3, min_moves: 3, title: "Dual Path Power",
  tiles: [
    { type: 'WIRE_CORNER', rot: 3, rotatable: true }, // Starts rot 3 (UP+RIGHT). 1 click -> rot 0 (DOWN+RIGHT)
    { type: 'WIRE_TEE', rot: 3, rotatable: true },    // Starts rot 3 (UP+RIGHT+LEFT). 2 clicks -> rot 1 (RIGHT+DOWN+LEFT)
    { type: 'BATTERY', channel: 'YELLOW', rot: 3, rotatable: false }, // LEFT into (0,1)

    { type: 'WIRE_STRAIGHT', rot: 0, rotatable: true }, // rot 0 (UP+DOWN)
    { type: 'BULB', channel: 'YELLOW', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },

    { type: 'WIRE_CORNER', rot: 3, rotatable: true }, // rot 3 (UP+RIGHT) into (2,1)
    { type: 'BULB', channel: 'YELLOW', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 8: 3x3 Video Circuit - Single Circuit (CYAN)
allLevels[8] = {
  rows: 3, cols: 3, min_moves: 2, title: "Video Circuit",
  tiles: [
    { type: 'BATTERY', channel: 'CYAN', rot: 1, rotatable: false }, // RIGHT into (0,1)
    { type: 'WIRE_TEE', rot: 0, rotatable: true },                  // 1 click -> rot 1 (RIGHT+DOWN+LEFT)
    { type: 'BULB', channel: 'CYAN', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'WIRE_STRAIGHT', rot: 1, rotatable: true },             // 1 click -> rot 0 (UP+DOWN)
    { type: 'EMPTY', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'FAN', channel: 'CYAN', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 9: 4x4 Grid Matrix - Single Circuit (CYAN)
allLevels[9] = {
  rows: 4, cols: 4, min_moves: 2, title: "Grid Matrix",
  tiles: [
    { type: 'BATTERY', channel: 'CYAN', rot: 1, rotatable: false },
    { type: 'WIRE_STRAIGHT', rot: 0, rotatable: true }, // 1 click -> rot 1 (horizontal)
    { type: 'WIRE_TEE', rot: 0, rotatable: true },      // 1 click -> rot 1 (RIGHT+DOWN+LEFT)
    { type: 'BULB', channel: 'CYAN', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'WIRE_STRAIGHT', rot: 0, rotatable: true },
    { type: 'EMPTY', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'WIRE_CORNER', rot: 3, rotatable: true }, // rot 3 (UP+RIGHT) into (2,3)
    { type: 'FAN', channel: 'CYAN', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 10: 4x4 Quad Network - Single Circuit (GREEN)
allLevels[10] = {
  rows: 4, cols: 4, min_moves: 2, title: "Quad Network",
  tiles: [
    { type: 'SOLAR', channel: 'GREEN', rot: 1, rotatable: false }, // RIGHT into (0,1)
    { type: 'RESISTOR', rot: 0, rotatable: true },                 // 1 click -> rot 1 (horizontal)
    { type: 'WIRE_CORNER', rot: 0, rotatable: true },               // 1 click -> rot 1 (DOWN+LEFT)
    { type: 'EMPTY', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'WIRE_STRAIGHT', rot: 0, rotatable: true },
    { type: 'EMPTY', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'WIRE_CORNER', rot: 3, rotatable: true },
    { type: 'FAN', channel: 'GREEN', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 11: 3x3 Solar Flow (GREEN)
allLevels[11] = {
  rows: 3, cols: 3, min_moves: 2, title: "Solar Flow",
  tiles: [
    { type: 'SOLAR', channel: 'GREEN', rot: 1, rotatable: false },
    { type: 'RESISTOR', rot: 0, rotatable: true }, // 1 click -> rot 1
    { type: 'WIRE_CORNER', rot: 0, rotatable: true }, // 1 click -> rot 1 (DOWN+LEFT)

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'WIRE_STRAIGHT', rot: 0, rotatable: true },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'HEATER', channel: 'GREEN', rot: 0, rotatable: false }
  ]
};

// Level 12: 3x3 Single Circuit Hybrid (YELLOW)
allLevels[12] = {
  rows: 3, cols: 3, min_moves: 2, title: "Hybrid Power",
  tiles: [
    { type: 'SOLAR', channel: 'YELLOW', rot: 1, rotatable: false },
    { type: 'RESISTOR', rot: 0, rotatable: true }, // 1 click -> rot 1 (horizontal)
    { type: 'WIRE_CORNER', rot: 0, rotatable: true }, // 1 click -> rot 1 (DOWN+LEFT)

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'BULB', channel: 'YELLOW', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 13: 3x3 Circuit Lab (ORANGE)
allLevels[13] = {
  rows: 3, cols: 3, min_moves: 2, title: "Circuit Lab",
  tiles: [
    { type: 'SOLAR', channel: 'ORANGE', rot: 1, rotatable: false },
    { type: 'RESISTOR', rot: 0, rotatable: true }, // 1 click -> rot 1
    { type: 'WIRE_CORNER', rot: 0, rotatable: true }, // 1 click -> rot 1

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'HEATER', channel: 'ORANGE', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 14: 3x3 Cooling System (CYAN)
allLevels[14] = {
  rows: 3, cols: 3, min_moves: 2, title: "Cooling System",
  tiles: [
    { type: 'BATTERY', channel: 'CYAN', rot: 1, rotatable: false },
    { type: 'RESISTOR', rot: 0, rotatable: true }, // 1 click -> rot 1
    { type: 'WIRE_CORNER', rot: 0, rotatable: true }, // 1 click -> rot 1

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'FAN', channel: 'CYAN', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 15: 3x3 Vacuum Valve (YELLOW)
allLevels[15] = {
  rows: 3, cols: 3, min_moves: 2, title: "Vacuum Valve",
  tiles: [
    { type: 'BATTERY', channel: 'YELLOW', rot: 1, rotatable: false },
    { type: 'RESISTOR', rot: 0, rotatable: true }, // 1 click -> rot 1
    { type: 'WIRE_CORNER', rot: 0, rotatable: true }, // 1 click -> rot 1

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'VACUUM_TUBE', channel: 'YELLOW', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Level 16: 3x3 Tesla Arc (MAGENTA)
allLevels[16] = {
  rows: 3, cols: 3, min_moves: 2, title: "Tesla Arc",
  tiles: [
    { type: 'SOLAR', channel: 'MAGENTA', rot: 1, rotatable: false },
    { type: 'RESISTOR', rot: 0, rotatable: true }, // 1 click -> rot 1
    { type: 'WIRE_CORNER', rot: 0, rotatable: true }, // 1 click -> rot 1

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'TESLA_COIL', channel: 'MAGENTA', rot: 0, rotatable: false },

    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false },
    { type: 'EMPTY', rot: 0, rotatable: false }
  ]
};

// Test and log all 16 levels:
console.log('--- AUDITING ALL 16 LEVELS (SINGLE CIRCUIT, 0 LIT INITIALLY) ---');
for (let lvl = 1; lvl <= 16; lvl++) {
  const l = allLevels[lvl];
  const res = solveLevel(l.rows, l.cols, l.tiles);
  const ok = res.solutions > 0 && !res.isInitiallySolved && res.initiallyLit === 0 && res.minClicks === l.min_moves;
  console.log(`Lvl ${lvl}: OK=${ok}, initiallyLit=${res.initiallyLit}, isInitiallySolved=${res.isInitiallySolved}, minClicks=${res.minClicks}, declaredMin=${l.min_moves}, sol=${res.solutions}, fullSol=${res.fullCircuitSolutions}`);
}
