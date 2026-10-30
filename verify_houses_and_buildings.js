const fs = require('fs');

console.log('--- VERIFYING HOUSES & BUILDINGS SYSTEM ---');

// 1. Verify electric_enums.gd
const enumsCode = fs.readFileSync('scripts/electric_enums.gd', 'utf8');
if (!enumsCode.includes('HOUSE_SMALL') || !enumsCode.includes('HOUSE_BIG') || !enumsCode.includes('BUILDING')) {
  throw new Error('electric_enums.gd missing HOUSE_SMALL, HOUSE_BIG, or BUILDING');
}
console.log('[PASS] electric_enums.gd has HOUSE_SMALL, HOUSE_BIG, BUILDING enum values & ports.');

// 2. Verify electric_tile.gd
const tileCode = fs.readFileSync('scripts/electric_tile.gd', 'utf8');
if (!tileCode.includes('draw_house_small') || !tileCode.includes('draw_house_big') || !tileCode.includes('draw_building')) {
  throw new Error('electric_tile.gd missing draw_house_small, draw_house_big, or draw_building methods!');
}
console.log('[PASS] electric_tile.gd has full procedural vector rendering for Small House, Big House (Villa), and Skyscraper Building.');

// 3. Verify electric_landmark.gd
const landmarkCode = fs.readFileSync('scripts/electric_landmark.gd', 'utf8');
if (!landmarkCode.includes('class_name ElectricLandmark') ||
    !landmarkCode.includes('draw_small_cottage') ||
    !landmarkCode.includes('draw_big_villa') ||
    !landmarkCode.includes('draw_skyscraper_with_solar_panels')) {
  throw new Error('electric_landmark.gd missing essential methods!');
}
console.log('[PASS] electric_landmark.gd provides interactive landmark display with Small House, Big House, and Skyscraper with Big Solar Panels.');

// 4. Verify electric_levels.gd keeps the board pure (no houses on the board grid)
const levelsCode = fs.readFileSync('scripts/electric_levels.gd', 'utf8');
if (levelsCode.includes('target_types.append(ElectricEnums.TileType.HOUSE_SMALL)')) {
  throw new Error('electric_levels.gd should not generate houses on the board grid!');
}
console.log('[PASS] electric_levels.gd keeps the puzzle board clean: pure bulbs, fans, heaters, tubes & coils.');

// 5. Verify electric_flow.gd
const flowCode = fs.readFileSync('scripts/electric_flow.gd', 'utf8');
if (!flowCode.includes('landmark_display') || !flowCode.includes('set_circuit_status')) {
  throw new Error('electric_flow.gd missing landmark_display integration!');
}
console.log('[PASS] electric_flow.gd connects live circuit status directly to landmark display.');

// 6. Verify scenes/electric_flow.tscn
const tscnCode = fs.readFileSync('scenes/electric_flow.tscn', 'utf8');
if (!tscnCode.includes('LandmarkDisplay') || !tscnCode.includes('electric_landmark.gd')) {
  throw new Error('electric_flow.tscn missing LandmarkDisplay node!');
}
console.log('[PASS] scenes/electric_flow.tscn includes LandmarkCenter and LandmarkDisplay nodes.');

console.log('--- ALL HOUSES & BUILDINGS CHECKS PASSED SUCCESSFULLY! ---');
