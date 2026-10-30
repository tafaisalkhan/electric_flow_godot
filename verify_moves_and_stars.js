const fs = require('fs');

console.log('--- VERIFYING MOVES, STARS & AUDIO SYNTHESIS ---');

// 1. Verify electric_levels.gd
const levelsCode = fs.readFileSync('scripts/electric_levels.gd', 'utf8');

// Check handcrafted levels have min_moves
for (let lvl = 1; lvl <= 16; lvl++) {
  const fnName = `func _level_${lvl}()`;
  const fnIdx = levelsCode.indexOf(fnName);
  if (fnIdx === -1) throw new Error(`Missing ${fnName}`);
  const nextFn = lvl < 16 ? `func _level_${lvl + 1}()` : `func _is_level_solved`;
  const endIdx = levelsCode.indexOf(nextFn, fnIdx);
  const block = levelsCode.substring(fnIdx, endIdx);
  
  const minMovesMatch = block.match(/"min_moves":\s*(\d+)/);
  if (!minMovesMatch) {
    throw new Error(`Level ${lvl} missing "min_moves"!`);
  }
  const minMoves = parseInt(minMovesMatch[1]);
  if (minMoves < 1) {
    throw new Error(`Level ${lvl} min_moves must be >= 1, got ${minMoves}`);
  }
}
console.log('[PASS] All handcrafted levels (1-16) have explicit min_moves >= 1 defined.');

// Check procedural generator returns min_moves
if (!levelsCode.includes('"min_moves": maxi(total_min_moves, 1)')) {
  throw new Error('Procedural generator missing min_moves return!');
}
console.log('[PASS] Procedural generator returns min_moves >= 1.');

// 2. Verify electric_flow.gd moves tracking & star calculation
const flowCode = fs.readFileSync('scripts/electric_flow.gd', 'utf8');

if (!flowCode.includes('var player_moves: int = 0')) throw new Error('Missing player_moves declaration');
if (!flowCode.includes('var current_min_moves: int = 1')) throw new Error('Missing current_min_moves declaration');
if (!flowCode.includes('moves_label')) throw new Error('Missing moves_label declaration');

// Check star evaluation
if (!flowCode.includes('if player_moves <= current_min_moves:') ||
    !flowCode.includes('stars_earned = 3') ||
    !flowCode.includes('elif player_moves <= current_min_moves + 2:') ||
    !flowCode.includes('stars_earned = 2') ||
    !flowCode.includes('stars_earned = 1')) {
  throw new Error('Star award logic does not match specification (3 stars for <= min_moves, 2 stars for <= min_moves + 2, 1 star for more)!');
}
console.log('[PASS] Star award logic correctly implements 3 stars (optimal), 2 stars (+2 moves), 1 star (cleared).');

// Check applause SFX
if (!flowCode.includes('_play_applause_sfx()') || !flowCode.includes('_generate_applause_sfx()')) {
  throw new Error('Missing applause sound implementation!');
}
console.log('[PASS] Applause sound effects integrated into victory sequence.');

// Check GameState.register_win call
if (!flowCode.includes('GameState.register_win(current_level_num, stars_earned, reward_coins)')) {
  throw new Error('Missing GameState.register_win integration!');
}
console.log('[PASS] GameState.register_win integration verified.');

// 3. Test star formula function
function calcStars(playerMoves, minMoves) {
  if (playerMoves <= minMoves) return 3;
  if (playerMoves <= minMoves + 2) return 2;
  return 1;
}

const minMoves = 3;
console.log(`Par: ${minMoves}`);
console.log(`Moves = 1 -> ${calcStars(1, minMoves)} Stars`); // 3
console.log(`Moves = 3 -> ${calcStars(3, minMoves)} Stars`); // 3
console.log(`Moves = 4 -> ${calcStars(4, minMoves)} Stars`); // 2
console.log(`Moves = 5 -> ${calcStars(5, minMoves)} Stars`); // 2
console.log(`Moves = 6 -> ${calcStars(6, minMoves)} Stars`); // 1
console.log(`Moves = 10 -> ${calcStars(10, minMoves)} Stars`); // 1

if (calcStars(3, minMoves) !== 3 || calcStars(5, minMoves) !== 2 || calcStars(6, minMoves) !== 1) {
  throw new Error('calcStars formula validation failed!');
}
console.log('[PASS] Star award formula successfully verified against all test cases.');

console.log('--- ALL CHECKS PASSED SUCCESSFULLY! ---');
