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

// Let's test Level 1:
// (0,0): SOLAR rot=1 -> RIGHT
// (0,1): WIRE_CORNER. Solved rot = 1 (DOWN + LEFT).
// Scramble: rot = 0 (RIGHT + DOWN). 1 click to solve!
console.log('Level 1 at rot 0:');
const l1_corner_ports = getActivePorts({ type: 'WIRE_CORNER', rot: 0 });
console.log('  rot 0 ports:', l1_corner_ports, 'Has LEFT (8)?', (l1_corner_ports & DIR_LEFT) !== 0);
// rot 0 has 2 | 4 (RIGHT | DOWN). No LEFT! So it is NOT connected!
// Player clicks once -> rot 1.
const l1_corner_solved = getActivePorts({ type: 'WIRE_CORNER', rot: 1 });
console.log('  rot 1 ports:', l1_corner_solved, 'Has LEFT and DOWN?', (l1_corner_solved & DIR_LEFT) !== 0 && (l1_corner_solved & DIR_DOWN) !== 0);
