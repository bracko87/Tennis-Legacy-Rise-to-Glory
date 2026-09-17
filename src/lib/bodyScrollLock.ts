let activeBodyScrollLocks = 0
let originalBodyOverflow = ''

export function lockBodyScroll() {
  if (typeof document === 'undefined') return () => undefined

  const body = document.body
  if (activeBodyScrollLocks === 0) {
    originalBodyOverflow = body.style.overflow
    body.style.overflow = 'hidden'
  }
  activeBodyScrollLocks += 1

  let released = false
  return () => {
    if (released) return
    released = true
    activeBodyScrollLocks = Math.max(0, activeBodyScrollLocks - 1)

    if (activeBodyScrollLocks === 0) {
      body.style.overflow = originalBodyOverflow
      originalBodyOverflow = ''
    }
  }
}
