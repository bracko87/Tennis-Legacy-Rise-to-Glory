import type { FormEvent } from 'react'
import { useState } from 'react'

import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'
import '../../styles/bug-report.css'

const SCREENSHOT_BUCKET = 'bug-report-screenshots'
const MAX_SCREENSHOT_BYTES = 5 * 1024 * 1024

type BugType = 'ui' | 'gameplay' | 'performance' | 'data' | 'other'
type Severity = 'low' | 'medium' | 'high'

interface BugReportButtonProps {
  collapsed?: boolean
  currentPageLabel: string
  currentPath: string
}

export default function BugReportButton({
  collapsed = false,
  currentPageLabel,
  currentPath,
}: BugReportButtonProps) {
  const { user, player } = useAuth()
  const [open, setOpen] = useState(false)
  const [bugType, setBugType] = useState<BugType>('ui')
  const [severity, setSeverity] = useState<Severity>('medium')
  const [description, setDescription] = useState('')
  const [expectedResult, setExpectedResult] = useState('')
  const [actualResult, setActualResult] = useState('')
  const [stepsToReproduce, setStepsToReproduce] = useState('')
  const [screenshotFile, setScreenshotFile] = useState<File | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)

  function resetForm() {
    setBugType('ui')
    setSeverity('medium')
    setDescription('')
    setExpectedResult('')
    setActualResult('')
    setStepsToReproduce('')
    setScreenshotFile(null)
    setError(null)
  }

  function closeModal() {
    if (submitting) return
    setOpen(false)
    setError(null)
  }

  function createReportId() {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID()
    }

    const bytes = new Uint8Array(16)
    if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
      crypto.getRandomValues(bytes)
    } else {
      for (let index = 0; index < bytes.length; index += 1) {
        bytes[index] = Math.floor(Math.random() * 256)
      }
    }

    // RFC 4122 UUID v4: set version and variant bits explicitly.
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80

    const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('')
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
  }

  function sanitizeFileName(fileName: string) {
    return fileName.replace(/[^a-zA-Z0-9._-]+/g, '_').slice(-120)
  }

  async function uploadScreenshot(userId: string, reportId: string) {
    if (!screenshotFile) return { path: null, url: null }

    if (!screenshotFile.type.startsWith('image/')) {
      throw new Error('The screenshot must be an image file.')
    }
    if (screenshotFile.size > MAX_SCREENSHOT_BYTES) {
      throw new Error('The screenshot must be 5 MB or smaller.')
    }

    const filePath = `${userId}/${reportId}/${Date.now()}-${sanitizeFileName(screenshotFile.name)}`
    const { error: uploadError } = await supabase.storage
      .from(SCREENSHOT_BUCKET)
      .upload(filePath, screenshotFile, { upsert: false })

    if (uploadError) throw uploadError

    const { data } = supabase.storage.from(SCREENSHOT_BUCKET).getPublicUrl(filePath)
    return { path: filePath, url: data.publicUrl }
  }

  async function submitReport(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setSuccess(false)

    const cleanDescription = description.trim()
    if (cleanDescription.length < 10) {
      setError('Please describe the issue in at least 10 characters.')
      return
    }
    if (!user || submitting) return

    setSubmitting(true)

    try {
      const reportId = createReportId()
      const screenshot = await uploadScreenshot(user.id, reportId)
      const viewport = typeof window !== 'undefined'
        ? `${window.innerWidth}x${window.innerHeight}`
        : null

      const { error: insertError } = await supabase.from('bug_reports').insert({
        id: reportId,
        user_id: user.id,
        player_id: player?.id ?? null,
        page_label: currentPageLabel,
        page_path: currentPath,
        page_url: typeof window !== 'undefined' ? window.location.href : null,
        bug_type: bugType,
        severity,
        description: cleanDescription,
        expected_result: expectedResult.trim() || null,
        actual_result: actualResult.trim() || null,
        steps_to_reproduce: stepsToReproduce.trim() || null,
        browser: typeof navigator !== 'undefined' ? navigator.userAgent : null,
        viewport,
        screenshot_path: screenshot.path,
        screenshot_url: screenshot.url,
        reported_from: 'sidebar',
        status: 'open',
      })

      if (insertError) throw insertError

      resetForm()
      setOpen(false)
      setSuccess(true)
      window.setTimeout(() => setSuccess(false), 3500)
    } catch (submissionError) {
      console.error('Unable to submit Tennis Legacy bug report:', submissionError)
      setError(
        submissionError instanceof Error
          ? submissionError.message
          : 'The report could not be sent. Please try again.',
      )
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <>
      <button
        type="button"
        className="tlg-bug-launcher"
        onClick={() => {
          setOpen(true)
          setError(null)
        }}
        title={`Report a bug from ${currentPageLabel}`}
      >
        <span>{collapsed ? 'Bug' : 'Report Bug'}</span>
        {!collapsed && <small>{currentPageLabel}</small>}
      </button>

      {success && !collapsed && (
        <div className="tlg-bug-success" role="status">Bug report sent. Thank you.</div>
      )}

      {open && (
        <div className="tlg-bug-modal-backdrop" role="presentation" onMouseDown={closeModal}>
          <div
            className="tlg-bug-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="tlg-bug-title"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <header className="tlg-bug-modal-header">
              <div>
                <span>REPORT A PROBLEM</span>
                <h2 id="tlg-bug-title">Report Bug</h2>
                <p>Current page: <strong>{currentPageLabel}</strong></p>
              </div>
              <button type="button" className="tlg-bug-close" onClick={closeModal} aria-label="Close bug report">×</button>
            </header>

            <form className="tlg-bug-form" onSubmit={submitReport}>
              <div className="tlg-bug-two-col">
                <label>
                  <span>Bug type</span>
                  <select value={bugType} onChange={(event) => setBugType(event.target.value as BugType)}>
                    <option value="ui">Interface / visual</option>
                    <option value="gameplay">Gameplay</option>
                    <option value="performance">Performance</option>
                    <option value="data">Wrong data</option>
                    <option value="other">Other</option>
                  </select>
                </label>
                <label>
                  <span>Severity</span>
                  <select value={severity} onChange={(event) => setSeverity(event.target.value as Severity)}>
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="high">High</option>
                  </select>
                </label>
              </div>

              <label>
                <span>What is wrong? *</span>
                <textarea
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  placeholder="Describe the problem clearly."
                  rows={4}
                  maxLength={4000}
                  required
                />
              </label>

              <div className="tlg-bug-two-col">
                <label>
                  <span>Expected result</span>
                  <textarea value={expectedResult} onChange={(event) => setExpectedResult(event.target.value)} rows={3} placeholder="What should have happened?" />
                </label>
                <label>
                  <span>Actual result</span>
                  <textarea value={actualResult} onChange={(event) => setActualResult(event.target.value)} rows={3} placeholder="What happened instead?" />
                </label>
              </div>

              <label>
                <span>Steps to reproduce</span>
                <textarea value={stepsToReproduce} onChange={(event) => setStepsToReproduce(event.target.value)} rows={3} placeholder="If known, tell us how to reproduce the issue." />
              </label>

              <label className="tlg-bug-file">
                <span>Screenshot · optional</span>
                <input
                  type="file"
                  accept="image/*"
                  onChange={(event) => setScreenshotFile(event.target.files?.[0] ?? null)}
                />
                <small>PNG/JPG/WebP or another image format, maximum 5 MB.</small>
              </label>

              {error && <div className="tlg-bug-error" role="alert">{error}</div>}

              <footer className="tlg-bug-actions">
                <button type="button" className="tlg-bug-secondary" onClick={closeModal} disabled={submitting}>Cancel</button>
                <button type="submit" className="tlg-bug-primary" disabled={submitting}>
                  {submitting ? 'Sending…' : 'Send report'}
                </button>
              </footer>
            </form>
          </div>
        </div>
      )}
    </>
  )
}
