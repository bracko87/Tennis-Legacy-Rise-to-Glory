// Helios H08: schema-review ledger consistency check.
// Pure file validation: no database/API credentials, production access or user data.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const path = resolve(repoRoot, 'docs/HELIOS_GUEST_ERASURE_180_TABLE_TRIAGE_LEDGER.md');
const source = readFileSync(path, 'utf8');
const rows = source.split('\n').filter((line) => /^\| \d+ \| `[^\x60]+` \|/.test(line));
const expectedCount = 180;
const expectedPaths = 818;
const names = new Set();
let sumPaths = 0;
let directTableCount = 0;
let indirectTableCount = 0;
for (let i = 0; i < rows.length; i++) {
  const cells = rows[i].split('|').slice(1, -1).map((cell) => cell.trim());
  if (cells.length !== 9) throw new Error(`Wrong column count at table row ${i + 1}`);
  const [number, table, depth, paths, directCount, action, group, proposed, status] = cells;
  if (Number(number) !== i + 1) throw new Error(`Invalid sequential index ${number}`);
  if (names.has(table)) throw new Error(`Duplicate table ${table}`);
  names.add(table);
  if (!/^\x60[^\x60]+\x60$/.test(table)) throw new Error(`Invalid table identifier ${table}`);
  if (!Number.isInteger(Number(depth)) || Number(depth) < 1 || Number(depth) > 12)
    throw new Error(`Invalid FK depth in ${table}`);
  if (!Number.isInteger(Number(paths)) || Number(paths) < 1)
    throw new Error(`Invalid path count in ${table}`);
  if (!Number.isInteger(Number(directCount)) || Number(directCount) < 0)
    throw new Error(`Invalid direct constraint count in ${table}`);
  if (!/^(IDENTITY_AUTH|PERSONAL_GAMEPLAY|FINANCIAL|PRIVATE_COMMUNICATION|COMPETITION_HISTORY)$/.test(group))
    throw new Error(`Unrecognized review group in ${table}`);
  if (!proposed || !action) throw new Error(`Empty candidate review metadata in ${table}`);
  if (status !== 'REVIEW_REQUIRED')
    throw new Error(`Unapproved retention/deletion action in ${table}: ${status}`);
  sumPaths += Number(paths);
  if (Number(directCount) > 0) directTableCount++;
  else indirectTableCount++;
}
if (rows.length !== expectedCount || sumPaths !== expectedPaths ||
    directTableCount !== 156 || indirectTableCount !== 24)
  throw new Error(`Unexpected FK ledger: ${rows.length} tables, ${sumPaths} paths, ${directTableCount} direct, ${indirectTableCount} indirect`);
console.log(`Helios erasure ledger PASS: ${rows.length} unique tables, ${sumPaths} paths, ${directTableCount} direct, ${indirectTableCount} indirect; all REVIEW_REQUIRED`);
