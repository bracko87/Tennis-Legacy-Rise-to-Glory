#!/usr/bin/env node
/**
 * CMD-friendly, local-backend-only UI startup. No Docker commands, keys,
 * remote database writes, or paid Supabase branches are needed here.
 * The one-time sandbox setup must have completed successfully first.
 *
 * Ordinary "npm run dev" stays unchanged for the existing live-connected UI.
 * "npm run dev:private-life" compiles the SAME UI for the isolated local stack.
 */
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { parsePrivateLifeLocalStatus } from './private-life-local-config.mjs'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const sandbox = path.join(root, '.private-life-sandbox')
const configFile = path.join(sandbox, 'supabase', 'config.toml')

if (!fs.existsSync(configFile)) {
  console.error('Private Life LOCAL sandbox is not set up. Run scripts\\setup-private-life-sandbox.cmd once after starting Docker Desktop.')
  process.exit(1)
}
if (!fs.readFileSync(configFile, 'utf8').includes('tennis_private_life_sandbox')) {
  console.error('Invalid isolated sandbox project. Refusing to connect to another database.')
  process.exit(1)
}

let statusOutput
try {
  if (process.platform === 'win32') {
    // CMD only, no PowerShell. CLI status reads the existing local stack.
    statusOutput = execFileSync('cmd.exe', ['/d', '/s', '/c', 'npx supabase status -o env'], {
      cwd: sandbox, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 25000,
      windowsHide: true, maxBuffer: 1024 * 1024,
    })
  } else {
    statusOutput = execFileSync('npx', ['supabase', 'status', '-o', 'env'], {
      cwd: sandbox, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 25000,
      maxBuffer: 1024 * 1024,
    })
  }
} catch {
  // Never print CLI output: it may contain service-role credentials.
  console.error('Isolated Supabase is not running. Start Docker Desktop, then from .private-life-sandbox run: npx supabase start')
  process.exit(1)
}

let local
try {
  local = parsePrivateLifeLocalStatus(statusOutput)
} catch (error) {
  console.error(error.message)
  process.exit(1)
}
process.env.TL_SUPABASE_URL = local.url
process.env.TL_SUPABASE_PUBLISHABLE_KEY = local.publishableKey
process.env.TL_DEV_PORT = process.env.TL_DEV_PORT || '8001'
console.log('PRIVATE LIFE LOCAL TEST: frontend uses isolated Docker Supabase at ' + local.url)
console.log('No live accounts, purchases or finance records are used.')
await import('./build.mjs')
