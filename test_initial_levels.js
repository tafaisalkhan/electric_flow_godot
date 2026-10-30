const fs = require('fs');
let code = fs.readFileSync('scratch_test_1000.js', 'utf8');

const cutIdx = code.indexOf('console.log("Generating and verifying 100 random procedural levels');
if (cutIdx !== -1) code = code.slice(0, cutIdx);

code += `
console.log('=== CHECKING INITIAL STATE OF HANDCRAFTED LEVELS 1 TO 16 ===');
for (let num = 1; num <= 16; num++) {
  const lvl = handcraftedLevels[num - 1];
  const rots = lvl.tiles.map(t => t.rot || 0);
  const isInitSolved = evaluateCircuit(lvl, rots);
  console.log('Level ' + num + ' (' + lvl.title + '): initial solved = ' + isInitSolved);
}
`;

eval(code);
