import fs from 'node:fs'

const path = 'src/components/player/AvatarReplacementRequestPanel.tsx'
let text = fs.readFileSync(path, 'utf8')

const marker = `async function validateImage(file: File) {
  if (file.size <= 0) throw new Error('Please choose a valid image file.')
`

const replacement = `function createSecureRequestId() {
  const cryptoApi = globalThis.crypto
  if (!cryptoApi) throw new Error('Secure random number generation is not supported by this browser.')

  if (typeof cryptoApi.randomUUID === 'function') return cryptoApi.randomUUID()
  if (typeof cryptoApi.getRandomValues !== 'function') {
    throw new Error('Secure random number generation is not supported by this browser.')
  }

  const bytes = cryptoApi.getRandomValues(new Uint8Array(16))
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0'))
  return \`${'${'}hex.slice(0, 4).join('')}-${'${'}hex.slice(4, 6).join('')}-${'${'}hex.slice(6, 8).join('')}-${'${'}hex.slice(8, 10).join('')}-${'${'}hex.slice(10, 16).join('')}\`
}

async function validateImage(file: File) {
  if (file.size <= 0) throw new Error('Please choose a valid image file.')
`

if (!text.includes(marker)) throw new Error('validateImage marker not found')
text = text.replace(marker, replacement)

const oldLine = '      const requestId = crypto.randomUUID()\n'
const newLine = '      const requestId = createSecureRequestId()\n'
if ((text.match(/const requestId = crypto\.randomUUID\(\)/g) ?? []).length !== 1) {
  throw new Error('Expected exactly one crypto.randomUUID() request id call')
}
text = text.replace(oldLine, newLine)

fs.writeFileSync(path, text)
