#!/usr/bin/env node
// scripts/ensure-marketing-version.mjs
//
// Makes sure MARKETING_VERSION in the Xcode project is high enough to be accepted
// by App Store Connect, so Xcode Cloud deliveries never fail again with
// ITMS-90186 ("train closed") / ITMS-90062 ("version must be higher").
//
// It asks App Store Connect (via the `asc` CLI) for the app's versions and their
// states. A version's "train" is CLOSED to new build uploads once it ships or
// enters review; it is OPEN while still editable. If the current MARKETING_VERSION
// sits on a CLOSED train (or is not higher than the latest shipped version), every
// MARKETING_VERSION entry is bumped to the next free patch. Otherwise nothing changes.
//
// Auth (asc reads these automatically):
//   CI:    ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_B64, ASC_APP_ID
//   Local: an `asc` profile, e.g.  --profile "Pillie ASO"  (or ASC_PROFILE)
//
// Usage:
//   node scripts/ensure-marketing-version.mjs                 # check + apply if needed
//   node scripts/ensure-marketing-version.mjs --check         # report only, exit 10 if a bump is needed
//   node scripts/ensure-marketing-version.mjs --profile "Pillie ASO"
//   node scripts/ensure-marketing-version.mjs --app 6759352439

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';

const PBXPROJ = 'Pillie/Pillie.xcodeproj/project.pbxproj';
const APP_ID = argOf('--app') || process.env.ASC_APP_ID || '6759352439';
const PROFILE = argOf('--profile') || process.env.ASC_PROFILE || '';
const CHECK_ONLY = process.argv.includes('--check');

// appStoreState values where the version's train is CLOSED to new build uploads.
// Anything not listed here (PREPARE_FOR_SUBMISSION, DEVELOPER_REJECTED, REJECTED,
// METADATA_REJECTED, INVALID_BINARY, ...) is treated as an OPEN, editable train.
const CLOSED_STATES = new Set([
  'READY_FOR_SALE', 'PENDING_APPLE_RELEASE', 'PENDING_DEVELOPER_RELEASE',
  'PROCESSING_FOR_APP_STORE', 'IN_REVIEW', 'WAITING_FOR_REVIEW',
  'PENDING_CONTRACT', 'REPLACED_WITH_NEW_VERSION', 'REMOVED_FROM_SALE',
  'ACCEPTED', 'PREORDER_READY_FOR_SALE',
]);

function argOf(flag) { const i = process.argv.indexOf(flag); return i >= 0 ? process.argv[i + 1] : null; }
function cmp(a, b) {
  const pa = a.split('.').map(Number), pb = b.split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) { const d = (pa[i] || 0) - (pb[i] || 0); if (d) return Math.sign(d); }
  return 0;
}
function bumpPatch(v) { const p = v.split('.').map(Number); while (p.length < 3) p.push(0); p[2]++; return p.slice(0, 3).join('.'); }

// 1. Current MARKETING_VERSION from the project file.
const pbx = readFileSync(PBXPROJ, 'utf8');
const found = [...pbx.matchAll(/MARKETING_VERSION = ([0-9.]+);/g)].map(m => m[1]);
if (!found.length) { console.error('No MARKETING_VERSION found in ' + PBXPROJ); process.exit(1); }
const distinct = [...new Set(found)];
const current = [...found].sort(cmp).at(-1);
console.log('Current MARKETING_VERSION: ' + current + (distinct.length > 1 ? ' (WARNING mixed values: ' + distinct.join(', ') + ')' : ''));

// 2. Ask App Store Connect for the versions.
const args = ['versions', 'list', '--app', APP_ID, '--platform', 'IOS', '--paginate', '--output', 'json'];
if (PROFILE) args.unshift('--profile', PROFILE);
let versions = [];
try {
  const out = execFileSync('asc', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  versions = (JSON.parse(out).data || []).map(v => ({ v: v.attributes.versionString, state: v.attributes.appStoreState }));
} catch (e) {
  // Non-fatal: if asc is missing or auth fails, leave the version untouched so the
  // rest of the run still proceeds. Nothing gets silently shipped at a bad version.
  console.error('Could not query App Store Connect via asc: ' + (e.stderr?.toString().trim() || e.message));
  console.error('Leaving MARKETING_VERSION unchanged.');
  process.exit(0);
}
console.log('App Store versions: ' + (versions.map(x => x.v + ' [' + x.state + ']').join(', ') || '(none)'));

// 3. Decide whether a bump is needed.
const closed = versions.filter(x => CLOSED_STATES.has(x.state));
const maxClosed = closed.map(x => x.v).sort(cmp).at(-1);
const currentEntry = versions.find(x => x.v === current);
let needBump = false, reason = '';
if (currentEntry && CLOSED_STATES.has(currentEntry.state)) { needBump = true; reason = current + ' is ' + currentEntry.state + ' (train closed)'; }
else if (maxClosed && cmp(current, maxClosed) <= 0) { needBump = true; reason = current + ' is not higher than shipped ' + maxClosed; }

if (!needBump) {
  console.log('No bump needed: ' + (currentEntry ? current + ' is ' + currentEntry.state + ' (train open).' : current + ' has no closed App Store train.'));
  process.exit(0);
}

// 4. Compute the next free version and apply.
const closedSet = new Set(closed.map(x => x.v));
let base = (maxClosed && cmp(maxClosed, current) > 0) ? maxClosed : current;
let target = bumpPatch(base);
while (closedSet.has(target) || cmp(target, current) <= 0) target = bumpPatch(target);
console.log('BUMP NEEDED: ' + current + ' -> ' + target + '  (' + reason + ')');
if (CHECK_ONLY) process.exit(10);

writeFileSync(PBXPROJ, pbx.replace(/MARKETING_VERSION = [0-9.]+;/g, 'MARKETING_VERSION = ' + target + ';'));
console.log('Updated all ' + found.length + ' MARKETING_VERSION entries to ' + target + ' in ' + PBXPROJ);

