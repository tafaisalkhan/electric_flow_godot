const fs = require('fs');
const content = fs.readFileSync('scripts/electric_levels.gd', 'utf8');

for (let i = 1; i <= 16; i++) {
  const start = content.indexOf(`static func _level_${i}()`);
  const end = content.indexOf(`static func _level_${i + 1}()`);
  const block = content.slice(start, end !== -1 ? end : start + 1200);
  console.log(`=== LEVEL ${i} ===`);
  const regex = /"type":\s*ElectricEnums\.TileType\.([A-Z_]+)[\s\S]*?"rot":\s*(\d+)[\s\S]*?"rotatable":\s*(true|false)/g;
  let m;
  while ((m = regex.exec(block)) !== null) {
    console.log(`  ${m[1]}: rot=${m[2]}, rotatable=${m[3]}`);
  }
}
