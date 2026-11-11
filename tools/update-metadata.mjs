import fs from 'node:fs/promises';
const get = async url => {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${response.status}: ${url}`);
  return response.json();
};
const versionUrl = 'https://clientsettingscdn.roblox.com/v2/client-version/WindowsStudio64/channel/LIVE';
const version = await get(versionUrl);
const url = `https://setup.rbxcdn.com/${version.clientVersionUpload}-API-Dump.json`;
const api = await get(url);
const classes = [];
let properties = 0;
for (const cls of api.Classes) {
  const entries = [];
  for (const member of cls.Members) {
    if (member.MemberType !== 'Property' || member.Name === 'Source') continue;
    const tags = member.Tags || [];
    if (tags.some(tag => ['Hidden', 'NotScriptable', 'Deprecated'].includes(tag))) continue;
    const read = member.Security?.Read ?? 'None';
    if (!['None', 'PluginSecurity'].includes(read)) continue;
    const readonly = tags.includes('ReadOnly') || !['None', 'PluginSecurity'].includes(member.Security?.Write ?? 'None');
    entries.push(`{${JSON.stringify(member.Name)},${JSON.stringify(member.Category || 'Other')},${readonly}}`);
    properties++;
  }
  classes.push(`[${JSON.stringify(cls.Name)}]={${JSON.stringify(cls.Superclass)},{${entries.join(',')}}}`);
}
await fs.writeFile('src/ApiMetadata.luau', `return {Version=${JSON.stringify(version.clientVersionUpload)},Classes={${classes.join(',')}}}\n`);
await fs.writeFile('dist/api-source.json', JSON.stringify({ version: version.clientVersionUpload, source: url, classes: api.Classes.length, properties }));
console.log(`Bundled official Roblox API metadata: ${api.Classes.length} classes, ${properties} public properties.`);
