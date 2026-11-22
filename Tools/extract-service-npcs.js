const fs = require('fs');
const path = require('path');
if (!process.argv[2] || !process.argv[3]) throw new Error('Usage: node Tools/extract-service-npcs.js <WaypointTracker_Data directory> <output file>');
const base = process.argv[2];
const raw = fs.readFileSync(path.join(base, 'Data.lua'), 'utf8');
const standardTypes = ['innkeeper', 'flight', 'repair', 'banker', 'auctioneer', 'stablemaster'];
const extractedTypes = [...standardTypes, 'vendor'];
const rosters = {};
for (const type of extractedTypes) {
  const line = raw.split(/\r?\n/).find(s => s.startsWith(type + '\t'));
  rosters[type] = new Map(line.split('\t')[1].split(',').map(v => { const [id, faction] = v.split(':'); return [Number(id), faction]; }));
}
const entries = new Map();
for (const file of ['Curated.lua', 'Forever.lua']) {
  for (const line of fs.readFileSync(path.join(base, file), 'utf8').split(/\r?\n/)) {
    const p = line.split('\t');
    if (p[0] !== 'N' || !p[1] || !p[2] || !p[6]) continue;
    const id = Number(p[1]);
    const roles = (p[5] || '').split(',');
    for (const type of extractedTypes) {
      const faction = rosters[type].get(id) || (roles.includes(type) ? p[7] : null);
      if (!['A', 'H', 'AH'].includes(faction)) continue;
      const matches = [];
      for (const part of p[6].split(';')) {
        const [map, coords] = part.split(':');
        if (!coords || !/^\d+$/.test(map)) continue;
        const xy = coords.split(',').map(Number);
        for (let i=0; i+1<xy.length; i+=2) {
          if (Number.isFinite(xy[i]) && Number.isFinite(xy[i+1]) && xy[i]>=0 && xy[i]<=1000 && xy[i+1]>=0 && xy[i+1]<=1000)
            matches.push([Number(map), xy[i]/1000, xy[i+1]/1000]);
        }
      }
      if (matches.length) entries.set(type + ':' + id, {type, id, name:p[2], faction, matches});
    }
  }
}
// Community service observations carry explicit faction, role, and precise map positions.
for (const line of fs.readFileSync(path.join(base, 'Forever.lua'), 'utf8').split(/\r?\n/)) {
  const p = line.split('\t');
  if (p[0] !== 'SN' || !p[6] || !['A','H','AH'].includes(p[2])) continue;
  for (const type of extractedTypes) {
    if (!(p[4] || '').split(',').includes(type)) continue;
    const [map, coords] = p[6].split(':');
    if (!coords || !/^\d+$/.test(map)) continue;
    const xy = coords.split(',').map(Number);
    if (!Number.isFinite(xy[0]) || !Number.isFinite(xy[1]) || xy[0]<0 || xy[0]>1 || xy[1]<0 || xy[1]>1) continue;
    entries.set(type + ':' + Number(p[1]), {type, id:Number(p[1]), name:p[3], faction:p[2], matches:[[Number(map),xy[0],xy[1]]]});
  }
}
// A merchant listed as selling both Arcane Powder and Infernal Stones has
// evidence of a reagent inventory. Stock can still differ in live Forever.
const sourceLines = fs.readFileSync(path.join(base, 'Sources.lua'), 'utf8').split(/\r?\n/);
const reagentVendors = [17020, 5565].map(item => {
  const row = sourceLines.find(line => line.startsWith(item + '\t'));
  return new Set(row ? (row.split('\t')[3] || '').split(',').map(Number) : []);
});
for (const entry of entries.values()) {
  if (entry.type === 'vendor' && reagentVendors.every(ids => ids.has(entry.id))) {
    entries.set('reagent:' + entry.id, {...entry, type:'reagent'});
  }
}
// Some records provide an explicit NPC title; do not infer reagent vendors
// from generic merchants, which can sell unrelated goods.
for (const line of fs.readFileSync(path.join(base, 'Forever.lua'), 'utf8').split(/\r?\n/)) {
  const p = line.split('\t');
  if (p[0] !== 'N' || !p[6] || !/\breagents?\b/i.test(p[8] || '')) continue;
  const id = Number(p[1]);
  const faction = rosters.vendor.get(id) || p[7];
  if (!['A', 'H', 'AH'].includes(faction)) continue;
  const matches = [];
  for (const part of p[6].split(';')) {
    const [map, coords] = part.split(':');
    if (!coords || !/^\d+$/.test(map)) continue;
    const xy = coords.split(',').map(Number);
    for (let i = 0; i + 1 < xy.length; i += 2) {
      if (Number.isFinite(xy[i]) && Number.isFinite(xy[i+1]) && xy[i] >= 0 && xy[i] <= 1000 && xy[i+1] >= 0 && xy[i+1] <= 1000)
        matches.push([Number(map), xy[i] / 1000, xy[i+1] / 1000]);
    }
  }
  if (matches.length) entries.set('reagent:' + id, {type:'reagent', id, name:p[2], faction, matches});
}

// Trainer rosters identify class or profession; positioned rows provide names
// and observed map coordinates. An ID can teach more than one profession.
const trainerText = fs.readFileSync(path.join(base, 'Trainers.lua'), 'utf8');
const trainerRosters = new Map();
for (const line of trainerText.split(/\r?\n/)) {
  const p = line.split('\t');
  if (!/^trainer_(class|profession)_/.test(p[0]) || !p[1]) continue;
  trainerRosters.set(p[0], new Map(p[1].split(',').map(v => { const [id, faction] = v.split(':'); return [Number(id), faction]; })));
}
for (const line of trainerText.split(/\r?\n/)) {
  const p = line.split('\t');
  if (!/^\d+$/.test(p[0]) || !p[1] || !p[2]) continue;
  const id = Number(p[0]);
  const matches = [];
  for (const part of p[2].split(';')) {
    const [map, coords] = part.split(':');
    if (!coords || !/^\d+$/.test(map)) continue;
    const xy = coords.split(',').map(Number);
    if (Number.isFinite(xy[0]) && Number.isFinite(xy[1]) && xy[0] >= 0 && xy[0] <= 1 && xy[1] >= 0 && xy[1] <= 1)
      matches.push([Number(map), xy[0], xy[1]]);
  }
  if (!matches.length) continue;
  for (const [type, roster] of trainerRosters) {
    const faction = roster.get(id);
    if (['A','H','AH'].includes(faction)) entries.set(type + ':' + id, {type, id, name:p[1], faction, matches});
  }
}
// Fall back to curated coordinates for rostered trainers lacking an observed
// position. Prefer trainerLocations where available.
for (const file of ['Curated.lua', 'Forever.lua']) {
  for (const line of fs.readFileSync(path.join(base, file), 'utf8').split(/\r?\n/)) {
    const p = line.split('\t');
    if (p[0] !== 'N' || !p[1] || !p[2] || !p[6]) continue;
    const id = Number(p[1]);
    const matches = [];
    for (const part of p[6].split(';')) {
      const [map, coords] = part.split(':');
      if (!coords || !/^\d+$/.test(map)) continue;
      const xy = coords.split(',').map(Number);
      for (let i = 0; i + 1 < xy.length; i += 2) {
        if (Number.isFinite(xy[i]) && Number.isFinite(xy[i+1]) && xy[i] >= 0 && xy[i] <= 1000 && xy[i+1] >= 0 && xy[i+1] <= 1000)
          matches.push([Number(map), xy[i] / 1000, xy[i+1] / 1000]);
      }
    }
    if (!matches.length) continue;
    for (const [type, roster] of trainerRosters) {
      const faction = roster.get(id);
      if (!entries.has(type + ':' + id) && ['A','H','AH'].includes(faction))
        entries.set(type + ':' + id, {type, id, name:p[2], faction, matches});
    }
  }
}
// Fill gaps in the service roster from the upstream travel network. These
// positions are less precise than explicit service observations, so never
// replace an existing location. Faction comes from the service roster.
const names = new Map();
for (const line of fs.readFileSync(path.join(base, 'Names_enUS.lua'), 'utf8').split(/\r?\n/)) {
  const p = line.split('\t');
  if (/^\d+$/.test(p[0]) && p[1] && !names.has(Number(p[0]))) names.set(Number(p[0]), p[1]);
}
const travelPath = path.join(base, '..', 'WaypointTracker', 'TravelData.lua');
for (const line of fs.readFileSync(travelPath, 'utf8').split(/\r?\n/)) {
  const p = line.split('\t');
  const match = /^INN_(\d+)$/.exec(p[0]);
  if (!match || p[1] !== 'inn') continue;
  const id = Number(match[1]);
  const faction = rosters.innkeeper.get(id);
  const map = Number(p[6]), x = Number((Number(p[7]) / 100).toFixed(6)), y = Number((Number(p[8]) / 100).toFixed(6));
  if (!entries.has('innkeeper:' + id) && ['A','H','AH'].includes(faction) && names.has(id)
      && map > 0 && Number.isFinite(x) && Number.isFinite(y) && x >= 0 && x <= 1 && y >= 0 && y <= 1) {
    entries.set('innkeeper:' + id, {type:'innkeeper', id, name:names.get(id), faction, matches:[[map,x,y]]});
  }
}
let out = '-- Generated service NPC locations; see Data/NPC_SOURCES.md for attribution.\nlocal _, ns = ...\n\nns.ServiceNPCs = {\n';
for (const type of [...standardTypes, 'reagent', ...trainerRosters.keys()]) {
  out += '    ' + type + ' = {\n';
  let count=0;
  for (const e of entries.values()) if(e.type===type) for (const pos of e.matches) {
    const name = JSON.stringify(e.name).replace(/\\u([0-9a-f]{4})/gi, (_,h)=>String.fromCharCode(parseInt(h,16)));
    out += `        { id = ${e.id}, name = ${name}, faction = "${e.faction}", map = ${pos[0]}, x = ${pos[1]}, y = ${pos[2]} },\n`;
    count++;
  }
  out += '    },\n';
  process.stdout.write(type + ': ' + count + ' positions\n');
}
out += '}\n';
fs.writeFileSync(process.argv[3], out, 'utf8');
