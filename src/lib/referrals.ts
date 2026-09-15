export const REFERRAL_CODE_STORAGE_KEY = 'tlg_referral_code'
const REFERRAL_BROWSER_INSTALL_KEY = 'tlg_referral_browser_install_id'

function bytesToHex(bytes: Uint8Array) {
  return Array.from(bytes, (value) => value.toString(16).padStart(2, '0')).join('')
}

export async function getReferralBrowserHash() {
  let installId = window.localStorage.getItem(REFERRAL_BROWSER_INSTALL_KEY)
  if (!installId) {
    installId = window.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`
    window.localStorage.setItem(REFERRAL_BROWSER_INSTALL_KEY, installId)
  }

  if (window.crypto?.subtle) {
    const encoded = new TextEncoder().encode(installId)
    const digest = await window.crypto.subtle.digest('SHA-256', encoded)
    return bytesToHex(new Uint8Array(digest))
  }

  return installId
}

export function getStoredReferralCode() {
  return (window.localStorage.getItem(REFERRAL_CODE_STORAGE_KEY) ?? '').trim().toUpperCase()
}

export function storeReferralCode(code: string) {
  window.localStorage.setItem(REFERRAL_CODE_STORAGE_KEY, code.trim().toUpperCase())
}

export function clearStoredReferralCode() {
  window.localStorage.removeItem(REFERRAL_CODE_STORAGE_KEY)
}
