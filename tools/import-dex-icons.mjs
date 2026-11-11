import fs from 'node:fs/promises';
const source = await fs.readFile('DexPlusPlus-main/modules/Lib.lua', 'utf8');
const section = source.match(/NewDark\s*=\s*\{\s*MapId\s*=\s*(\d+),\s*Icons\s*=\s*\{([\s\S]*?)\},\s*IconSize\s*=\s*(\d+),\s*Witdh\s*=\s*(\d+)/);
if (!section) throw new Error('NewDark icon map not found');
const entries = [...section[2].matchAll(/(\w+)\s*=\s*(\d+)/g)];
await fs.writeFile('src/IconAtlas.luau', `return { Image = "rbxassetid://${section[1]}", Size = ${section[3]}, Columns = ${section[4]}, Classes = {\n${entries.map(([, name, index]) => `\t${name} = ${Number(index) - 1},`).join('\n')}\n} }\n`);
const license = await fs.readFile('DexPlusPlus-main/LICENSE', 'utf8');
await fs.writeFile('THIRD_PARTY_NOTICES.md', `# Third-party notices\n\nThe class icon mapping and atlas reference in src/IconAtlas.luau are adapted from DexPlusPlus, modules/Lib.lua (NewDark map).\n\nUpstream: https://github.com/AZYsGithub/DexPlusPlus\n\n${license}\n\nThe icon artwork is provided by the referenced Roblox asset and remains subject to its owners' rights.\n`);
console.log(`Imported ${entries.length} class icon mappings; retained DexPlusPlus MIT notice.`);
