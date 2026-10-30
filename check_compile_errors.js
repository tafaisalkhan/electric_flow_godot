const fs = require('fs');
const path = require('path');

console.log('====================================================');
console.log('       COMPREHENSIVE PROJECT COMPILE / PARSE AUDIT  ');
console.log('====================================================\n');

let totalErrors = 0;
let totalWarnings = 0;

// 1. Check all preload("res://...") paths exist on disk
console.log('--- 1. VERIFYING ALL PRELOAD PATHS ---');
const scriptsDir = 'scripts';
const gdFiles = fs.readdirSync(scriptsDir).filter(f => f.endsWith('.gd'));

for (const file of gdFiles) {
  const filePath = path.join(scriptsDir, file);
  const code = fs.readFileSync(filePath, 'utf8');
  const lines = code.split('\n');

  for (let lineNum = 1; lineNum <= lines.length; lineNum++) {
    const line = lines[lineNum - 1];
    const preloadMatches = line.matchAll(/preload\s*\(\s*["']res:\/\/([^"']+)["']\s*\)/g);
    for (const match of preloadMatches) {
      const resPath = match[1];
      if (!fs.existsSync(resPath)) {
        console.error(`[ERROR] ${file}:${lineNum} Preload target does not exist: "res://${resPath}"`);
        totalErrors++;
      }
    }
  }
}
console.log(`Preload check done. (Current errors: ${totalErrors})\n`);

// 2. Check for Godot 4 ":=" type inference hazards
console.log('--- 2. VERIFYING GDScript 4 ":=" TYPE INFERENCE SAFETY ---');
// Cases where GDScript 4 parser fails with "Cannot infer type":
// - var x := arr[i] where arr is untyped
// - var x := something.call(...)
// - var x := dict.get(...)
// - var x := dict[key]
// - var x := untyped_func(...)
for (const file of gdFiles) {
  const filePath = path.join(scriptsDir, file);
  const code = fs.readFileSync(filePath, 'utf8');
  const lines = code.split('\n');

  for (let lineNum = 1; lineNum <= lines.length; lineNum++) {
    const line = lines[lineNum - 1];
    const trimmed = line.trim();
    if (trimmed.startsWith('#')) continue;

    // Check for := with .call(
    if (/var\s+\w+\s*:=\s*.*\.call\(/.test(trimmed)) {
      console.error(`[ERROR] ${file}:${lineNum} Unsafe ":=" on .call() expression (will cause "Cannot infer the type" error):`);
      console.error(`        ${trimmed}`);
      totalErrors++;
    }

    // Check for := with .get(
    if (/var\s+\w+\s*:=\s*.*\.get\(/.test(trimmed) && !trimmed.includes('get_node') && !trimmed.includes('get_parent')) {
      console.warn(`[WARNING] ${file}:${lineNum} Potential ":=" on .get() dictionary call: ${trimmed}`);
      totalWarnings++;
    }

    // Check for := with array index where array was literal untyped
    const inferIndexMatch = trimmed.match(/var\s+(\w+)\s*:=\s*(\w+)\[([^\]]+)\]/);
    if (inferIndexMatch) {
      const varName = inferIndexMatch[1];
      const arrName = inferIndexMatch[2];
      // Check how arrName was declared in previous lines of the same function
      let isUntypedArray = false;
      for (let prev = Math.max(0, lineNum - 50); prev < lineNum - 1; prev++) {
        const prevLine = lines[prev].trim();
        if (prevLine.includes(`var ${arrName} := [`) || prevLine.includes(`var ${arrName} = [`)) {
          isUntypedArray = true;
          break;
        }
      }
      if (isUntypedArray) {
        console.error(`[ERROR] ${file}:${lineNum} Unsafe ":=" on untyped array indexing ${arrName}[...]:`);
        console.error(`        ${trimmed}`);
        totalErrors++;
      }
    }
  }
}
console.log(`Type inference check done. (Current errors: ${totalErrors}, warnings: ${totalWarnings})\n`);

// 3. Check Bracket / Parenthesis / Brace balancing
console.log('--- 3. CHECKING BRACKETS, PARENS & BRACES BALANCING ---');
for (const file of gdFiles) {
  const filePath = path.join(scriptsDir, file);
  const code = fs.readFileSync(filePath, 'utf8');
  const lines = code.split('\n');

  let parenCount = 0;
  let bracketCount = 0;
  let braceCount = 0;
  let inMultilineString = false;

  for (let lineNum = 1; lineNum <= lines.length; lineNum++) {
    const rawLine = lines[lineNum - 1];
    let stripped = rawLine;

    // Remove comments
    const hashIdx = stripped.indexOf('#');
    if (hashIdx !== -1) {
      // Check if # is inside string
      const beforeHash = stripped.substring(0, hashIdx);
      const quotesBefore = (beforeHash.match(/"/g) || []).length;
      if (quotesBefore % 2 === 0) {
        stripped = beforeHash;
      }
    }

    // Remove quoted strings
    stripped = stripped.replace(/"(?:[^"\\]|\\.)*"/g, '""');
    stripped = stripped.replace(/'(?:[^'\\]|\\.)*'/g, "''");

    for (const char of stripped) {
      if (char === '(') parenCount++;
      else if (char === ')') parenCount--;
      else if (char === '[') bracketCount++;
      else if (char === ']') bracketCount--;
      else if (char === '{') braceCount++;
      else if (char === '}') braceCount--;
    }
  }

  if (parenCount !== 0 || bracketCount !== 0 || braceCount !== 0) {
    console.error(`[ERROR] ${file} Unbalanced syntax: parens delta=${parenCount}, brackets delta=${bracketCount}, braces delta=${braceCount}`);
    totalErrors++;
  }
}
console.log(`Balancing check done. (Current errors: ${totalErrors})\n`);

// 4. Verify Scene Unique Names (%UniqueName) in electric_flow
console.log('--- 4. VERIFYING SCENE UNIQUE NAMES IN electric_flow ---');
const flowScript = fs.readFileSync('scripts/electric_flow.gd', 'utf8');
const tscnContent = fs.readFileSync('scenes/electric_flow.tscn', 'utf8');

// Match only @onready var ... = %NodeName
const uniqueNameMatches = flowScript.matchAll(/=\s*%([A-Z]\w+)/g);
for (const m of uniqueNameMatches) {
  const uName = m[1];
  // Check if uName exists in tscn
  if (!tscnContent.includes(`name="${uName}"`)) {
    console.error(`[ERROR] electric_flow.gd references unique name %${uName}, but it is NOT found in electric_flow.tscn!`);
    totalErrors++;
  } else {
    // Check if unique_name_in_owner is true for this node
    const nodeIdx = tscnContent.indexOf(`name="${uName}"`);
    const nextNodeIdx = tscnContent.indexOf(`[node `, nodeIdx + 1);
    const nodeChunk = tscnContent.substring(nodeIdx, nextNodeIdx !== -1 ? nextNodeIdx : nodeIdx + 400);
    if (!nodeChunk.includes('unique_name_in_owner = true')) {
      console.error(`[ERROR] Node "${uName}" exists in electric_flow.tscn but missing "unique_name_in_owner = true"!`);
      totalErrors++;
    }
  }
}
console.log(`Scene unique names check done. (Current errors: ${totalErrors})\n`);

// 5. Verify electric_landmark.gd exports and references
console.log('--- 5. VERIFYING electric_landmark.gd INTEGRATION ---');
const landmarkScript = fs.readFileSync('scripts/electric_landmark.gd', 'utf8');
// Check method signatures match electric_flow.gd usage
const expectedMethods = ['configure_level', 'set_circuit_status'];
for (const method of expectedMethods) {
  if (!landmarkScript.includes(`func ${method}`)) {
    console.error(`[ERROR] electric_landmark.gd missing required method: func ${method}`);
    totalErrors++;
  }
}

// Check ThemeDB or fallback font in landmark
if (landmarkScript.includes('ThemeDB.fallback_font')) {
  console.log('[NOTE] Checked ThemeDB font fallback in electric_landmark.gd.');
}

// 6. Verify electric_tile.gd tile_type match covers all TileTypes used in levels
console.log('--- 6. VERIFYING electric_tile.gd COVERS ALL TILE TYPES ---');
const tileScript = fs.readFileSync('scripts/electric_tile.gd', 'utf8');
const enumScript = fs.readFileSync('scripts/electric_enums.gd', 'utf8');

const enumBlock = enumScript.substring(enumScript.indexOf('enum TileType {'), enumScript.indexOf('}', enumScript.indexOf('enum TileType {')));
const enumMembers = enumBlock.match(/\b[A-Z0-9_]+\b/g).filter(m => m !== 'TileType');

for (const member of enumMembers) {
  if (member === 'EMPTY') continue;
  if (!tileScript.includes(`ElectricEnums.TileType.${member}`)) {
    console.warn(`[WARNING] electric_tile.gd does not reference TileType.${member}`);
    totalWarnings++;
  }
}

// 7. Verify electric_levels.gd solver targets
console.log('--- 7. VERIFYING electric_levels.gd SOLVER TARGETS ---');
const levelsScript = fs.readFileSync('scripts/electric_levels.gd', 'utf8');
const targetTypes = ['BULB', 'FAN', 'VACUUM_TUBE', 'HEATER', 'TESLA_COIL'];
for (const t of targetTypes) {
  if (!levelsScript.includes(`ElectricEnums.TileType.${t}`)) {
    console.error(`[ERROR] electric_levels.gd solver missing target TileType.${t}`);
    totalErrors++;
  }
}

console.log('====================================================');
console.log(`FINAL RESULT: ${totalErrors} ERRORS, ${totalWarnings} WARNINGS`);
console.log('====================================================');

if (totalErrors === 0) {
  console.log('>>> COMPLETE PROJECT AUDIT PASSED WITH 0 ERRORS! <<<');
} else {
  console.log('>>> FOUND ISSUES THAT MUST BE FIXED! <<<');
  process.exit(1);
}
