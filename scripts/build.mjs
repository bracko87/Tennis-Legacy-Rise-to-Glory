import * as esbuild from 'esbuild'
import { cp } from 'node:fs/promises'
import { rimraf } from 'rimraf'
import stylePlugin from 'esbuild-style-plugin'
import autoprefixer from 'autoprefixer'
import tailwindcss from 'tailwindcss'

const args = process.argv.slice(2)
const isProd = args[0] === '--production'
const compileLocal = args[0] === '--compile-local'

const configuredUrl = process.env.TL_SUPABASE_URL?.trim() ?? ''
const configuredKey = process.env.TL_SUPABASE_PUBLISHABLE_KEY?.trim() ?? ''
if (Boolean(configuredUrl) !== Boolean(configuredKey)) {
  throw new Error('Set BOTH TL_SUPABASE_URL and TL_SUPABASE_PUBLISHABLE_KEY for local backend testing.')
}
if (isProd && (configuredUrl || configuredKey)) {
  throw new Error('A production build must not override the configured live backend. Remove local test variables.')
}
if (!isProd && !configuredUrl) {
  console.warn('LOCALHOST WARNING: Connecting to the existing LIVE Supabase project. Private Life database migrations are NOT deployed there. Configure an isolated backend to test this feature.')
}
const browserBackendUrl = configuredUrl || 'https://cwfznmroiqcyhfkfcrow.supabase.co'
const browserBackendKey = configuredKey || 'sb_publishable_FpDi8rEB6r1Ai49UMS_R2Q__UAGburi'

await rimraf('dist')

// Static marketing/game assets live in public/ and must be available from the
// site root in both local esbuild serve mode and production builds.
await cp('public', 'dist', { recursive: true })

/**
 * @type {esbuild.BuildOptions}
 */
const esbuildOpts = {
  color: true,
  entryPoints: ['src/main.tsx', 'index.html'],
  outdir: 'dist',
  entryNames: '[name]',
  write: true,
  bundle: true,
  format: 'iife',
  sourcemap: isProd ? false : 'linked',
  minify: isProd,
  treeShaking: true,
  jsx: 'automatic',
  // Root-relative mock assets are copied from public/ to dist/ above and are
  // intentionally resolved by the browser at runtime rather than bundled.
  external: ['/mock/*'],
  loader: {
    '.html': 'copy',
    '.png': 'file',
    '.webp': 'file',
  },
  // esbuild substitutes these at compile time, without browser-exposed secrets.
  define: {
    __TL_SUPABASE_URL__: JSON.stringify(browserBackendUrl),
    __TL_SUPABASE_PUBLISHABLE_KEY__: JSON.stringify(browserBackendKey),
  },
  plugins: [
    stylePlugin({
      postcss: {
        plugins: [tailwindcss, autoprefixer],
      },
    }),
  ],
}

if (isProd || compileLocal) {
  await esbuild.build(esbuildOpts)
} else {
  const ctx = await esbuild.context(esbuildOpts)
  await ctx.watch()
  const localPort = Number(process.env.TL_DEV_PORT || '8000')
  if (!Number.isInteger(localPort) || localPort < 1 || localPort > 65535) {
    throw new Error('TL_DEV_PORT must be a valid port between 1 and 65535.')
  }
  const { hosts, port } = await ctx.serve({
    servedir: 'dist',
    fallback: 'index.html',
    port: localPort,
  })
  console.log(`Running on:`)
  hosts.forEach((host) => {
    console.log(`http://${host}:${port}`)
  })
}
