// Keep intentional mixed case; normalize common entry mistakes only.
const surnameParticles = new Set(['da','das','de','del','della','den','der','di','do','dos','du','la','le','van','von','ten','ter','bin','ibn','al'])

export function normalizePlayerName(value: string, isSurname = false): string {
  const words = value.trim().split(/\s+/)
  const uniform = value === value.toLowerCase() || value === value.toUpperCase()
  return words.map((word, index) => {
    const lower = word.toLowerCase()
    if (isSurname && index < words.length - 1 && surnameParticles.has(lower) && (uniform || word === lower)) return lower
    if (!/^[\p{L}'’-]+$/u.test(word)) return word
    if (word === lower || (word === word.toUpperCase() && [...word].length > 2) || /^\p{Lu}{2}\p{Ll}{2,}$/u.test(word)) {
      return lower.replace(/(^|['’-])(\p{L})/gu, (_, prefix, letter) => prefix + letter.toUpperCase())
    }
    return word
  }).join(' ')
}
