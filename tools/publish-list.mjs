import fs from 'node:fs/promises';
const files = ['README.md', '.gitignore', 'default.project.json', 'dist/manifest.json'];
for (const directory of ['src', 'tools', 'executor', 'dist/modules']) {
  for (const file of (await fs.readdir(directory)).sort()) files.push(`${directory}/${file}`);
}
if (process.argv.includes('--loader')) files.push('loader.luau', 'dist/release.json');
const entries = [];
for (const file of files) entries.push({ path: file, mode: '100644', type: 'blob', content: await fs.readFile(file, 'utf8') });
process.stdout.write(JSON.stringify(entries));
