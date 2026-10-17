// Validate the *raw* Brazilian Portuguese overrides, not the merged English fallback.
// Run: node scripts/check-pt-coverage.mjs (requires npm dependencies to be installed).
import { build } from 'esbuild'

const { outputFiles } = await build({
  stdin: {
    contents: "import en from './src/i18n/locales/en.ts'; import { portugueseTranslations as pt } from './src/i18n/locales/pt.ts'; export { en, pt };",
    resolveDir: process.cwd(),
    sourcefile: 'locale-coverage-entry.ts',
    loader: 'ts',
  },
  bundle: true,
  platform: 'node',
  format: 'esm',
  write: false,
  logLevel: 'silent',
})
const source = Buffer.from(outputFiles[0].text).toString('base64')
const { en, pt } = await import(`data:text/javascript;base64,${source}`)

const missing = []
const wrongTypes = []
const wrongPlaceholders = []
const extra = []
const sameAsEnglish = []
let total = 0
let translated = 0

const isObject = v => v !== null && typeof v === 'object' && !Array.isArray(v)
const placeholders = text => [...String(text).matchAll(/\{\{\s*([^}]+?)\s*\}\}/g)].map(m => m[1]).sort().join('|')

function visit(reference, target, path = '') {
  if (typeof reference === 'string') {
    total++
    if (typeof target !== 'string') {
      (target === undefined ? missing : wrongTypes).push(path)
      return
    }
    translated++
    if (placeholders(reference) !== placeholders(target)) wrongPlaceholders.push(path)
    if (reference === target) sameAsEnglish.push(path)
    return
  }
  if (Array.isArray(reference)) {
    if (!Array.isArray(target)) {
      for (let i = 0; i < reference.length; i++) visit(reference[i], undefined, `${path}[${i}]`)
    } else {
      for (let i = 0; i < reference.length; i++) visit(reference[i], target[i], `${path}[${i}]`)
    }
    return
  }
  if (!isObject(reference)) return
  for (const [key, value] of Object.entries(reference)) visit(value, isObject(target) ? target[key] : undefined, path ? `${path}.${key}` : key)
  if (isObject(target)) for (const key of Object.keys(target)) {
    if (!(key in reference)) extra.push(path ? `${path}.${key}` : key)
  }
}
visit(en, pt)
const sections = {}
for (const item of missing) {
  const first = item.split(/[.\[]/)[0]
  sections[first] = (sections[first] || 0) + 1
}
console.log(`Portuguese coverage: ${translated}/${total} source strings (${(translated / total * 100).toFixed(1)}%)`)
console.log('Missing by section:', JSON.stringify(sections, null, 2))
for (const [label, values] of [['Missing translation keys', missing], ['Wrong value types', wrongTypes], ['Placeholder mismatches', wrongPlaceholders], ['Extra keys', extra]]) {
  console.log(`${label}: ${values.length}`)
  if (values.length) console.log(values.slice(0, 25).join('\n') + (values.length > 25 ? '\n…' : ''))
}
console.log(`Translated values identical to English (manual review candidates): ${sameAsEnglish.length}`)
if (missing.length || wrongTypes.length || wrongPlaceholders.length || extra.length) process.exitCode = 1
