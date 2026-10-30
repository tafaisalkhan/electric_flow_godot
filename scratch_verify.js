const fs = require('fs');

// Run scratch_check_levels on the newly edited electric_levels.gd!
const { execSync } = require('child_process');
const output = execSync('node scratch_check_levels.js', { encoding: 'utf8' });
console.log(output);
