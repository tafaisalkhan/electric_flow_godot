const fs = require('fs');
const auditCode = fs.readFileSync('audit_single_circuits.js', 'utf8');

// Extract allLevels from audit_single_circuits.js
const startIdx = auditCode.indexOf('allLevels[1] = {');
const endIdx = auditCode.indexOf('console.log(\'--- AUDITING');
const dictBlock = auditCode.substring(startIdx, endIdx);
global.allLevels = {};
eval(dictBlock);

let gdLevelsCode = '';
for (let lvl = 1; lvl <= 16; lvl++) {
  const l = allLevels[lvl];
  gdLevelsCode += `# Level ${lvl}: ${l.rows}x${l.cols} - ${l.title}\n`;
  gdLevelsCode += `static func _level_${lvl}() -> Dictionary:\n`;
  gdLevelsCode += `\treturn {\n`;
  gdLevelsCode += `\t\t"level": ${lvl},\n`;
  gdLevelsCode += `\t\t"rows": ${l.rows},\n`;
  gdLevelsCode += `\t\t"cols": ${l.cols},\n`;
  gdLevelsCode += `\t\t"title": "${l.title}",\n`;
  gdLevelsCode += `\t\t"min_moves": ${l.min_moves},\n`;
  gdLevelsCode += `\t\t"tiles": [\n`;
  
  for (let r = 0; r < l.rows; r++) {
    for (let c = 0; c < l.cols; c++) {
      const idx = r * l.cols + c;
      const t = l.tiles[idx];
      let tStr = `\t\t\t{"type": ElectricEnums.TileType.${t.type}`;
      if (t.channel) {
        tStr += `, "channel": ElectricEnums.Channel.${t.channel}`;
      }
      if (t.type !== 'EMPTY') {
        tStr += `, "rot": ${t.rot}, "rotatable": ${t.rotatable ? 'true' : 'false'}`;
      }
      tStr += `}`;
      if (idx < l.tiles.length - 1) tStr += `,`;
      gdLevelsCode += tStr + `\n`;
    }
    if (r < l.rows - 1) gdLevelsCode += `\n`;
  }
  gdLevelsCode += `\t\t]\n`;
  gdLevelsCode += `\t}\n\n`;
}

// Read current electric_levels.gd
const fullGd = fs.readFileSync('scripts/electric_levels.gd', 'utf8');
const headEnd = fullGd.indexOf('# Level 1:');
const tailStart = fullGd.indexOf('# HELPER: Check if a tile array is currently solved in its given rotation state');

let newGd = fullGd.substring(0, headEnd) + gdLevelsCode + fullGd.substring(tailStart);

// Update _generate_procedural_level to ensure circuit_count is ALWAYS 1:
newGd = newGd.replace(
  /var circuit_count := 1[\s\S]*?elif level_num > 80:\s*circuit_count = 2/,
  'var circuit_count := 1 # Strictly 1 circuit per level across entire game'
);

fs.writeFileSync('C:/Users/Supreme Traders/.gemini/antigravity-cli/brain/c56e7ac1-ee83-40f2-818a-1404ec5ab09c/scratch/new_electric_levels.gd', newGd);
console.log('Successfully wrote to scratch/new_electric_levels.gd, length:', newGd.length);
