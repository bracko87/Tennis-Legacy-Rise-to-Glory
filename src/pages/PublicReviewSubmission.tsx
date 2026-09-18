import { useEffect, useState } from 'react'
import {
  ArrowLeft,
  CheckCircle2,
  Send,
  Star,
} from 'lucide-react'
import { Link } from 'react-router'

import { useAuth } from '../auth/AuthContext'
import { supabase } from '../lib/supabase'

const LOGO_URL = 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Branding/logo%20333.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9CcmFuZGluZy9sb2dvIDMzMy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzg3OTQ1MDc5LCJleHAiOjQ5MTAwMDkwNzl9.Q7Ocay_B1kouWo_XmmgtVcGOCh0xtzhzaIm713AhU-ci-xJPY3JanaT3xhdkptAuKV5kUJGHov34fSM2TGjmcQ'

export default function PublicReviewSubmissionPage() {
  const { user, player } = useAuth()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [rating, setRating] = useState(5)
  const [reviewText, setReviewText] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [submitted, setSubmitted] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (player) {
      setName((current) => current || [player.first_name, player.last_name].filter(Boolean).join(' '))
    }

    if (user?.email) {
      setEmail((current) => current || user.email || '')
    }
  }, [player, user?.email])

  async function submitReview(event: React.FormEvent) {
    event.preventDefault()
    setError(null)

    const cleanName = name.trim()
    const cleanEmail = email.trim()
    const cleanText = reviewText.trim()

    if (cleanName.length < 2) {
      setError('Please enter your name.')
      return
    }

    if (!/^\S+@\S+\.\S+$/.test(cleanEmail)) {
      setError('Please enter a valid email address.')
      return
    }

    if (cleanText.length < 20) {
      setError('Please write at least 20 characters.')
      return
    }

    setSubmitting(true)
    const { error: rpcError } = await supabase.rpc('submit_public_homepage_review_v1', {
      p_reviewer_name: cleanName,
      p_reviewer_email: cleanEmail,
      p_rating: rating,
      p_review_text: cleanText,
    })
    setSubmitting(false)

    if (rpcError) {
      setError(rpcError.message)
      return
    }

    setSubmitted(true)
  }

  return (
    <main className="tlg-public-review-page">
      <div className="tlg-public-review-glow tlg-public-review-glow-one" />
      <div className="tlg-public-review-glow tlg-public-review-glow-two" />

      <header className="tlg-public-review-header">
        <Link to="/" className="tlg-public-review-logo-link" aria-label="Back to Tennis Legacy homepage">
          <img src={LOGO_URL} alt="Tennis Legacy: Rise to Glory" />
        </Link>
        <Link to="/" className="tlg-public-review-back">
          <ArrowLeft size={16} />
          Back to homepage
        </Link>
      </header>

      <section className="tlg-public-review-card">
        {submitted ? (
          <div className="tlg-public-review-success">
            <span className="tlg-public-review-success-icon"><CheckCircle2 size={30} /></span>
            <span className="tlg-section-eyebrow">Review received</span>
            <h1>Thank you for sharing your opinion.</h1>
            <p>
              Your review is now waiting for administrator approval. It will appear on the Tennis Legacy homepage only after it has been approved.
            </p>
            <Link to="/">Return to homepage</Link>
          </div>
        ) : (
          <>
            <div className="tlg-public-review-intro">
              <span className="tlg-section-eyebrow">Share your experience</span>
              <h1>Leave a Tennis Legacy review</h1>
              <p>
                You do not need a Tennis Legacy account to leave a review. Your email is used only for moderation and is never shown publicly.
              </p>
              {player && (
                <small>
                  You are signed in as {player.first_name} {player.last_name}. Your review will be linked to your player profile automatically.
                </small>
              )}
            </div>

            <form className="tlg-public-review-form" onSubmit={submitReview}>
              <div className="tlg-public-review-fields">
                <label>
                  <span>Your name</span>
                  <input
                    type="text"
                    value={name}
                    onChange={(event) => setName(event.target.value)}
                    maxLength={80}
                    autoComplete="name"
                    placeholder="Your name"
                    required
                  />
                </label>

                <label>
                  <span>Email</span>
                  <input
                    type="email"
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    maxLength={254}
                    autoComplete="email"
                    placeholder="you@example.com"
                    required
                  />
                </label>
              </div>

              <fieldset className="tlg-public-review-rating-fieldset">
                <legend>Rating</legend>
                <div className="tlg-public-review-rating">
                  {Array.from({ length: 5 }, (_, index) => {
                    const value = index + 1
                    return (
                      <button
                        key={value}
                        type="button"
                        className={value <= rating ? 'is-active' : undefined}
                        onClick={() => setRating(value)}
                        aria-label={'Rate ' + value + ' out of 5'}
                      >
                        <Star size={28} fill={value <= rating ? 'currentColor' : 'none'} />
                      </button>
                    )
                  })}
                  <strong>{rating}/5</strong>
                </div>
              </fieldset>

              <label className="tlg-public-review-textarea-label">
                <span>Your review</span>
                <textarea
                  value={reviewText}
                  onChange={(event) => setReviewText(event.target.value)}
                  minLength={20}
                  maxLength={700}
                  rows={8}
                  placeholder="Tell us what you think about Tennis Legacy..."
                  required
                />
                <small>{reviewText.trim().length}/700 characters</small>
              </label>

              <div className="tlg-public-review-moderation-note">
                Reviews are not published automatically. An administrator will review every submission first.
              </div>

              {error && <div className="tlg-public-review-error">{error}</div>}

              <button className="tlg-public-review-submit" type="submit" disabled={submitting}>
                <Send size={17} />
                {submitting ? 'Sending review…' : 'Send Review for Approval'}
              </button>
            </form>
          </>
        )}
      </section>
    </main>
  )
}
