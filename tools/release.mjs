import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const root = process.cwd();
const minifierPath = process.env.EXPLORER_MINIFIER || 'C:/Users/Asus/Documents/minifier';
const { minify } = await import(pathToFileURL(path.join(minifierPath, 'src/index.js')).href);
const output = path.join(root, 'dist/modules');
await fs.mkdir(output, { recursive: true });
const compress = source => {
  let best = minify(source, { level: 3, removeComments: true });
  for (let pass = 0; pass < 5; pass++) {
    const next = minify(best, { level: 3, removeComments: true });
    if (Buffer.byteLength(next) >= Buffer.byteLength(best)) break;
    best = next;
  }
  return best;
};
const checksum = text => {
  let a = 1, b = 0;
  for (const byte of Buffer.from(text)) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return b * 65536 + a;
};
const manifest = [];
let before = 0, after = 0;
for (const file of (await fs.readdir(path.join(root, 'src'))).sort()) {
  if (!file.endsWith('.luau') || file === 'init.client.luau') continue;
  const name = file.slice(0, -5);
  let source = await fs.readFile(path.join(root, 'src', file), 'utf8');
  source = source.replace(/require\(script\.Parent\.(\w+)\)/g, (_, dependency) => `Import("${dependency}")`);
  if (/require\(script/.test(source)) throw new Error(`Unconverted dependency in ${file}`);
  const result = compress(`return function(Import)\n${source}\nend`);
  await fs.writeFile(path.join(output, file), result);
  before += Buffer.byteLength(source);
  after += Buffer.byteLength(result);
  manifest.push([name, Buffer.byteLength(result), checksum(result)]);
}
await fs.writeFile('dist/manifest.json', JSON.stringify(manifest));
const revision = process.argv[2];
if (revision) {
  if (!/^[a-f0-9]{40}$/.test(revision)) throw new Error('Expected a full module commit SHA');
  const entries = manifest.map(([name, size, sum]) => `{${JSON.stringify(name)},${size},${sum}}`).join(',');
  const template = await fs.readFile('executor/loader.template.luau', 'utf8');
  const source = template.replace('__REVISION__', revision).replace('__MANIFEST__', `{${entries}}`);
  await fs.writeFile('loader.luau', compress(source));
  await fs.writeFile('dist/release.json', JSON.stringify({ repository: 'pldsp/explorer', modulesCommit: revision, modules: manifest.length, level: 3 }));
}
console.log(`Minified ${manifest.length} separate modules: ${before} -> ${after} bytes (${(100 - after / before * 100).toFixed(1)}% smaller).${revision ? ' Built pinned loader.' : ''}`);
