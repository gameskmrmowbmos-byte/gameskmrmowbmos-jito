const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function javaScriptFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) return javaScriptFiles(fullPath);
    return entry.isFile() && entry.name.endsWith('.js') ? [fullPath] : [];
  });
}

const roots = ['src', 'scripts', 'tests'].map((name) =>
  path.join(process.cwd(), name),
);
const files = roots.flatMap(javaScriptFiles);
let failed = false;

for (const file of files) {
  const result = spawnSync(process.execPath, ['--check', file], {
    encoding: 'utf8',
  });
  if (result.status !== 0) {
    failed = true;
    process.stderr.write(result.stderr || result.error?.message || `${file} failed syntax check\n`);
  }
}

if (failed) process.exit(1);
process.stdout.write(`Syntax check passed for ${files.length} JavaScript files.\n`);

