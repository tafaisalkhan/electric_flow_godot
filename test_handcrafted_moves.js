const fs = require('fs');

const DIR_UP = 1;
const DIR_RIGHT = 2;
const DIR_DOWN = 4;
const DIR_LEFT = 8;

const TileType = {
  EMPTY: 0,
  WIRE_STRAIGHT: 1,
  WIRE_CORNER: 2,
  WIRE_TEE: 3,
  WIRE_CROSS: 4,
  BATTERY: 5,
  BULB: 6,
  SOLAR: 7,
  FAN: 8,
  RESISTOR: 9,
  CAPACITOR: 10,
  VACUUM_TUBE: 11,
  HEATER: 12,
  TESLA_COIL: 13
};

function get_base_ports(type) {
  switch(type) {
    case TileType.WIRE_STRAIGHT:
    case TileType.RESISTOR:
    case TileType.CAPACITOR:
      return DIR_UP | DIR_DOWN;
    case TileType.WIRE_CORNER:
      return DIR_DOWN | DIR_RIGHT;
    case TileType.WIRE_TEE:
      return DIR_LEFT | DIR_DOWN | DIR_RIGHT;
    case TileType.WIRE_CROSS:
      return DIR_UP | DIR_RIGHT | DIR_DOWN | DIR_LEFT;
    case TileType.BATTERY:
    case TileType.SOLAR:
      return DIR_UP;
    case TileType.BULB:
    case TileType.FAN:
    case TileType.VACUUM_TUBE:
    case TileType.HEATER:
    case TileType.TESLA_COIL:
      return DIR_UP | DIR_RIGHT | DIR_DOWN | DIR_LEFT;
    default:
      return 0;
  }
}

function rotate_mask_cw(mask, steps) {
  let res = mask;
  steps = (steps % 4 + 4) % 4;
  for (let s = 0; s < steps; s++) {
    let n = 0;
    if (res & DIR_UP) n |= DIR_RIGHT;
    if (res & DIR_RIGHT) n |= DIR_DOWN;
    if (res & DIR_DOWN) n |= DIR_LEFT;
    if (res & DIR_LEFT) n |= DIR_UP;
    res = n;
  }
  return res;
}

function get_dir_offset(dir) {
  if (dir === DIR_UP) return [-1, 0];
  if (dir === DIR_RIGHT) return [0, 1];
  if (dir === DIR_DOWN) return [1, 0];
  if (dir === DIR_LEFT) return [0, -1];
  return [0, 0];
}

function get_opp(dir) {
  if (dir === DIR_UP) return DIR_DOWN;
  if (dir === DIR_RIGHT) return DIR_LEFT;
  if (dir === DIR_DOWN) return DIR_UP;
  if (dir === DIR_LEFT) return DIR_RIGHT;
  return 0;
}

function is_solved(tiles, rows, cols) {
  const queue = [];
  const visited = new Set();
  for (let i = 0; i < tiles.length; i++) {
    const t = tiles[i];
    if (t.type === TileType.BATTERY || t.type === TileType.SOLAR) {
      queue.push({ idx: i, ch: t.channel || 0 });
      visited.add(`${i}:${t.channel || 0}`);
    }
  }

  function get_ports(idx) {
    const t = tiles[idx];
    if (t.type === TileType.EMPTY) return 0;
    let base = t.ports || get_base_ports(t.type);
    return rotate_mask_cw(base, t.rot || 0);
  }

  const powered = new Set();
  const dirs = [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT];

  while (queue.length > 0) {
    const { idx: curr_idx, ch: curr_ch } = queue.shift();
    const curr_r = Math.floor(curr_idx / cols);
    const curr_c = curr_idx % cols;
    const curr_p = get_ports(curr_idx);

    for (let d of dirs) {
      if ((curr_p & d) === 0) continue;
      const [dr, dc] = get_dir_offset(d);
      const nr = curr_r + dr;
      const nc = curr_c + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      const n_idx = nr * cols + nc;
      const n_tile = tiles[n_idx];
      if (n_tile.type === TileType.EMPTY) continue;
      const opp_d = get_opp(d);
      const n_p = get_ports(n_idx);
      if ((n_p & opp_d) === 0) continue;

      const is_target = (
        n_tile.type === TileType.BULB ||
        n_tile.type === TileType.FAN ||
        n_tile.type === TileType.VACUUM_TUBE ||
        n_tile.type === TileType.HEATER ||
        n_tile.type === TileType.TESLA_COIL
      );

      if (is_target) {
        if (!n_tile.channel || n_tile.channel === curr_ch) {
          powered.add(n_idx);
          const key = `${n_idx}:${curr_ch}`;
          if (!visited.has(key)) {
            visited.add(key);
            queue.push({ idx: n_idx, ch: curr_ch });
          }
        }
      } else if (n_tile.type !== TileType.BATTERY && n_tile.type !== TileType.SOLAR) {
        powered.add(n_idx);
        const key = `${n_idx}:${curr_ch}`;
        if (!visited.has(key)) {
          visited.add(key);
          queue.push({ idx: n_idx, ch: curr_ch });
        }
      }
    }
  }

  const targets = [];
  for (let i = 0; i < tiles.length; i++) {
    const t = tiles[i];
    if (
      t.type === TileType.BULB ||
      t.type === TileType.FAN ||
      t.type === TileType.VACUUM_TUBE ||
      t.type === TileType.HEATER ||
      t.type === TileType.TESLA_COIL
    ) {
      targets.push(i);
    }
  }
  if (targets.length === 0) return false;
  return targets.every(idx => powered.has(idx));
}

function solve_bfs(level) {
  const rot_indices = [];
  for (let i = 0; i < level.tiles.length; i++) {
    if (level.tiles[i].rotatable) {
      rot_indices.push(i);
    }
  }

  const start_rots = rot_indices.map(idx => level.tiles[idx].rot || 0);
  const queue = [{ rots: start_rots, moves: 0 }];
  const visited = new Set();
  visited.add(start_rots.join(','));

  const cloneTiles = (rots) => {
    return level.tiles.map((t, i) => {
      const rotIdx = rot_indices.indexOf(i);
      if (rotIdx !== -1) {
        return { ...t, rot: rots[rotIdx] };
      }
      return { ...t };
    });
  };

  while (queue.length > 0) {
    const { rots, moves } = queue.shift();
    const currentTiles = cloneTiles(rots);
    if (is_solved(currentTiles, level.rows, level.cols)) {
      return { moves, solved_rots: rots, rot_indices };
    }

    for (let i = 0; i < rot_indices.length; i++) {
      const next_rots = [...rots];
      next_rots[i] = (next_rots[i] + 1) % 4;
      const key = next_rots.join(',');
      if (!visited.has(key)) {
        visited.add(key);
        queue.push({ rots: next_rots, moves: moves + 1 });
      }
    }
  }
  return { moves: -1 };
}

// Test Level 1 to 16
const code = fs.readFileSync('scripts/electric_levels.gd', 'utf8');

for (let lvl = 1; lvl <= 16; lvl++) {
  const fnName = `func _level_${lvl}()`;
  const fnIdx = code.indexOf(fnName);
  if (fnIdx === -1) {
    console.log(`Could not find ${fnName}`);
    continue;
  }
  let endIdx = -1;
  if (lvl < 16) {
    endIdx = code.indexOf(`func _level_${lvl + 1}()`, fnIdx);
  } else {
    endIdx = code.indexOf(`func _is_level_solved`, fnIdx);
  }
  const block = code.substring(fnIdx, endIdx !== -1 ? endIdx : fnIdx + 3000);

  const rowsMatch = block.match(/"rows":\s*(\d+)/);
  const colsMatch = block.match(/"cols":\s*(\d+)/);
  if (!rowsMatch || !colsMatch) {
    console.log(`Failed on level ${lvl}, block snippet:`, block.substring(0, 100));
    continue;
  }
  const rows = parseInt(rowsMatch[1]);
  const cols = parseInt(colsMatch[1]);

  const tileMatches = block.substring(block.indexOf('"tiles": [')).match(/\{[^}]+\}/g);
  const tiles = [];
  for (let tm of tileMatches) {
    let type = 0;
    if (tm.includes('WIRE_STRAIGHT')) type = TileType.WIRE_STRAIGHT;
    else if (tm.includes('WIRE_CORNER')) type = TileType.WIRE_CORNER;
    else if (tm.includes('WIRE_TEE')) type = TileType.WIRE_TEE;
    else if (tm.includes('WIRE_CROSS')) type = TileType.WIRE_CROSS;
    else if (tm.includes('BATTERY')) type = TileType.BATTERY;
    else if (tm.includes('BULB')) type = TileType.BULB;
    else if (tm.includes('SOLAR')) type = TileType.SOLAR;
    else if (tm.includes('FAN')) type = TileType.FAN;
    else if (tm.includes('RESISTOR')) type = TileType.RESISTOR;
    else if (tm.includes('CAPACITOR')) type = TileType.CAPACITOR;
    else if (tm.includes('VACUUM_TUBE')) type = TileType.VACUUM_TUBE;
    else if (tm.includes('HEATER')) type = TileType.HEATER;
    else if (tm.includes('TESLA_COIL')) type = TileType.TESLA_COIL;
    else if (tm.includes('EMPTY')) type = TileType.EMPTY;

    let rot = 0;
    const rotM = tm.match(/"rot":\s*(\d+)/);
    if (rotM) rot = parseInt(rotM[1]);

    let rotatable = tm.includes('"rotatable": true');

    let channel = 0;
    if (tm.includes('CYAN')) channel = 1;
    else if (tm.includes('YELLOW')) channel = 2;
    else if (tm.includes('MAGENTA')) channel = 3;
    else if (tm.includes('GREEN')) channel = 4;
    else if (tm.includes('RED')) channel = 5;

    tiles.push({ type, rot, rotatable, channel });
  }

  const res = solve_bfs({ rows, cols, tiles });
  const rotCount = tiles.filter(t => t.rotatable).length;
  console.log(`Level ${lvl} (${rows}x${cols}): rotatable=${rotCount}, min_moves=${res.moves}`);
}
