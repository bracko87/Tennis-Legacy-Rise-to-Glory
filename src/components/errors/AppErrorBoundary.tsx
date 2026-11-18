import { Component, type ErrorInfo, type ReactNode } from 'react'

interface Props {
  children: ReactNode
}

interface State {
  error: Error | null
}

/**
 * Keeps a React render/lifecycle exception from producing a featureless black
 * screen. This is a recovery UI, not a substitute for fixing the exception.
 */
export default class AppErrorBoundary extends Component<Props, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('[Tennis Legacy] Unhandled React render error:', error, info.componentStack)
  }

  render() {
    if (!this.state.error) return this.props.children

    return (
      <main
        role="alert"
        style={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '24px',
          background: '#080e18',
          color: '#f3f7fb',
          fontFamily: 'Arial, sans-serif',
        }}
      >
        <section style={{ maxWidth: 540, width: '100%', textAlign: 'center' }}>
          <h1 style={{ fontSize: 26, marginBottom: 16 }}>This page could not load</h1>
          <p style={{ lineHeight: 1.6 }}>
            Tennis Legacy encountered an unexpected display error. Your game progress is not changed by this message.
          </p>
          <p style={{ lineHeight: 1.6 }}>
            Try reloading once. If it happens again, please report the page address and the error shown in the browser console.
          </p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, justifyContent: 'center', marginTop: 24 }}>
            <button
              type="button"
              onClick={() => window.location.reload()}
              style={{ background: '#d1a855', color: '#101820', padding: '12px 18px', borderRadius: 8, fontWeight: 700, cursor: 'pointer' }}
            >
              Reload page
            </button>
            <a href="/" style={{ color: '#f3f7fb', padding: '12px 18px', border: '1px solid #607087', borderRadius: 8, textDecoration: 'none' }}>
              Back to home
            </a>
          </div>
        </section>
      </main>
    )
  }
}
