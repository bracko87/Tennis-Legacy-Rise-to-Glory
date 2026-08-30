import * as esbuild from 'esbuild'
import { cp } from 'node:fs/promises'
import { rimraf } from 'rimraf'
import stylePlugin from 'esbuild-style-plugin'
import autoprefixer from 'autoprefixer'
import tailwindcss from 'tailwindcss'

const args = process.argv.slice(2)
const isProd = args[0] === '--production'

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
  loader: {
    '.html': 'copy',
    '.png': 'file',
    '.webp': 'file',
  },
  plugins: [
    stylePlugin({
      postcss: {
        plugins: [tailwindcss, autoprefixer],
      },
    }),
  ],
}

if (isProd) {
  await esbuild.build(esbuildOpts)
} else {
  const ctx = await esbuild.context(esbuildOpts)
  await ctx.watch()
  const { hosts, port } = await ctx.serve({
    servedir: 'dist',
    fallback: 'index.html',
  })
  console.log(`Running on:`)
  hosts.forEach((host) => {
    console.log(`http://${host}:${port}`)
  })
}
