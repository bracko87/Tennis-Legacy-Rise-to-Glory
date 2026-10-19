import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'

const read = (path) => readFileSync(path, 'utf8')
const routes = [
  ['/', 'index.html'],
  ['/about/', 'public/about/index.html'],
  ['/features/', 'public/features/index.html'],
  ['/how-to-play/', 'public/how-to-play/index.html'],
]
const origin = 'https://tennislegacygame.com'
const sitemap = read('dist/sitemap.xml')
const urls = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1])
assert.equal(urls.length, routes.length, 'Four public canonical pages expected in sitemap')
assert.equal(new Set(urls).size, urls.length, 'Duplicate sitemap URLs')
assert.ok(urls.every((url) => url.startsWith(origin + '/')), 'Sitemap must use HTTPS production URLs')
assert.ok(!urls.some((url) => /\/(game|login|register|r|reviews|reset-password|create-player)\b/.test(url)),
  'Private, authenticated or user-specific pages must never be in sitemap')
const robots = read('dist/robots.txt')
assert.ok(robots.includes('Sitemap: ' + origin + '/sitemap.xml'), 'robots.txt must advertise sitemap')
assert.ok(robots.includes('Allow: /'), 'Public crawl access missing')
assert.ok(!robots.includes('Disallow: /game/'), 'Disallow would prevent processing X-Robots-Tag')
assert.ok(existsSync('dist/tennis-legacy-icon.svg'), 'Icon missing from production build')
assert.ok(existsSync('dist/marketing/atp-player.webp'), 'Social artwork missing')
assert.ok(existsSync('dist/seo-pages.css'), 'Public page CSS missing')

for (const [route, source] of routes) {
  const canonical = origin + route
  assert.ok(urls.includes(canonical), route + ': missing from sitemap')
  const built = read(route === '/' ? 'dist/index.html' : 'dist' + route + 'index.html')
  assert.match(built, /^<!doctype html>/i, route + ': expected valid HTML')
  assert.match(built, /<title>[^<]+<\/title>/i, route + ': missing title')
  assert.ok(built.includes('rel="canonical" href="' + canonical + '"'), route + ': wrong canonical URL')
  assert.match(built, /<meta name="description"/i, route + ': missing description')
  assert.match(built, /<meta property="og:title"/i, route + ': missing social title')
  assert.match(built, /<meta property="og:description"/i, route + ': missing social description')
  assert.match(built, /<meta property="og:image"/i, route + ': missing social image')
  assert.match(built, /<h1[\s>]/i, route + ': no server-readable H1')
  assert.ok(!built.includes('noindex'), route + ': accidentally set noindex')
  assert.ok(!built.includes('<![CDATA['), route + ': stray CDATA')
  assert.ok(!built.includes('localhost'), route + ': localhost reference')
  if (route !== '/') {
    assert.ok(built.includes('href="/login"'), route + ': missing game sign-in link')
    assert.ok(!built.includes('href="/register"'), route + ': registration is closed; public CTA cannot point to /register')
    assert.ok(built.includes('New-player registration is currently unavailable.'), route + ': missing truthful registration status')
    assert.ok(built.includes('href="/features/"'), route + ': missing navigation')
  }
  const input = read(source)
  assert.ok(input.length > 500, route + ': empty source content')
}
const home = read('dist/index.html')
assert.ok(home.includes('name="tennis-legacy-contact"'), 'Preserve Netlify contact form')
const jsonLd = home.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)
assert.ok(jsonLd, 'Structured data missing from homepage')
const schema = JSON.parse(jsonLd[1])
const game = schema['@graph'].find((node) => node['@type'] === 'VideoGame')
const website = schema['@graph'].find((node) => node['@type'] === 'WebSite')
const studio = schema['@graph'].find((node) => node['@type'] === 'Organization')
assert.equal(game?.url, origin + '/')
assert.equal(website?.url, origin + '/')
assert.equal(studio?.url, 'https://www.nextqueststudio.net/')
assert.equal(game?.publisher?.['@id'], studio['@id'])

const netlify = read('netlify.toml')
for (const route of ['/game/*','/login','/register','/forgot-password','/reset-password','/create-player','/reviews/*','/r/*']) {
  assert.ok(netlify.includes('for = "' + route + '"'), route + ': no X-Robots-Tag rule')
}
const wildcard = netlify.lastIndexOf('from = "/*"')
assert.ok(wildcard >= 0, 'SPA fallback must be kept')
assert.ok(netlify.includes('X-Robots-Tag = "noindex'), 'Missing private noindex headers')
assert.ok(netlify.includes('to = "/index.html"'), 'SPA fallback changed')
console.log('Tennis Legacy SEO validation passed: four public canonical routes, sitemap, metadata, schema, assets, and noindex coverage.')
