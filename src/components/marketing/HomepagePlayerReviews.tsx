import { useEffect, useRef, useState } from 'react'
import {
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Quote,
  Send,
  Star,
  X,
} from 'lucide-react'
import { useNavigate } from 'react-router'

import { useAuth } from '../../auth/AuthContext'
import { supabase } from '../../lib/supabase'

interface PublicReview {
  id: string
  player_name: string
  country_code: string
  world: 'ATP' | 'WTA'
  rating: number
  review_text: string
  approved_at: string | null
}

interface MyReview {
  exists: boolean
  id?: string
  status?: 'pending' | 'approved' | 'rejected'
  rating?: number
  review_text?: string
  submitted_at?: string
  reviewed_at?: string | null
}

function flagForCountry(code: string) {
  const upper = String(code || '').toUpperCase()
  if (!/^[A-Z]{2}$/.test(upper)) return '🌐'
  return String.fromCodePoint(...upper.split('').map((char) => 127397 + char.charCodeAt(0)))
}

export default function HomepagePlayerReviews() {
  const navigate = useNavigate()
  const { user, player, authLoading } = useAuth()
  const trackRef = useRef<HTMLDivElement | null>(null)
  const [reviews, setReviews] = useState<PublicReview[]>([])
  const [reviewsLoading, setReviewsLoading] = useState(true)
  const [myReview, setMyReview] = useState<MyReview | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [rating, setRating] = useState(5)
  const [reviewText, setReviewText] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  async function loadPublicReviews() {
    setReviewsLoading(true)
    const { data, error } = await supabase.rpc('get_public_homepage_reviews_v1', { p_limit: 30 })
    if (error) {
      console.warn('Unable to load player reviews:', error.message)
      setReviews([])
    } else {
      setReviews((data ?? []) as PublicReview[])
    }
    setReviewsLoading(false)
  }

  async function loadMyReview() {
    if (!user || !player) {
      setMyReview(null)
      return
    }
    const { data, error } = await supabase.rpc('get_my_homepage_review_v1')
    if (error) {
      console.warn('Unable to load your review status:', error.message)
      return
    }
    const current = (data ?? { exists: false }) as MyReview
    setMyReview(current)
    if (current.exists && current.status === 'rejected') {
      setRating(Number(current.rating) || 5)
      setReviewText(current.review_text ?? '')
    }
  }

  useEffect(() => {
    void loadPublicReviews()
  }, [])

  useEffect(() => {
    if (!authLoading) void loadMyReview()
  }, [authLoading, user?.id, player?.id])

  useEffect(() => {
    if (!modalOpen) return
    const previous = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = previous
    }
  }, [modalOpen])

  function scroll(direction: -1 | 1) {
    const node = trackRef.current
    if (!node) return
    node.scrollBy({
      left: direction * Math.max(280, node.clientWidth * 0.86),
      behavior: 'smooth',
    })
  }

  function openReviewForm() {
    setNotice(null)
    setFormError(null)

    if (authLoading) return
    if (!user) {
      navigate('/login')
      return
    }
    if (!player) {
      navigate('/create-player')
      return
    }
    if (myReview?.exists && myReview.status === 'pending') {
      setNotice('Your review is already waiting for administrator approval.')
      return
    }
    if (myReview?.exists && myReview.status === 'approved') {
      setNotice('Your review has already been approved and is published on the homepage.')
      return
    }

    if (!myReview?.exists) {
      setRating(5)
      setReviewText('')
    }
    setModalOpen(true)
  }

  async function submitReview(event: React.FormEvent) {
    event.preventDefault()
    const text = reviewText.trim()
    setFormError(null)

    if (text.length < 20) {
      setFormError('Please write at least 20 characters.')
      return
    }
    if (text.length > 700) {
      setFormError('Review cannot exceed 700 characters.')
      return
    }

    setSubmitting(true)
    const { error } = await supabase.rpc('submit_homepage_review_v1', {
      p_rating: rating,
      p_review_text: text,
    })
    setSubmitting(false)

    if (error) {
      setFormError(error.message)
      return
    }

    setModalOpen(false)
    setNotice('Thank you. Your review was sent to the administrators and will appear here only after approval.')
    await loadMyReview()
  }

  const actionLabel =
    myReview?.status === 'pending'
      ? 'Review Pending'
      : myReview?.status === 'approved'
        ? 'Review Published'
        : myReview?.status === 'rejected'
          ? 'Edit & Resubmit Review'
          : 'Add Review'

  return (
    <section className="tlg-player-reviews-section" aria-labelledby="player-reviews-title">
      <div className="tlg-section">
        <div className="tlg-player-reviews-heading">
          <div>
            <span className="tlg-section-eyebrow">Player Reviews</span>
            <h2 id="player-reviews-title" className="tlg-section-title">What managers say about Tennis Legacy</h2>
            <p className="tlg-section-description">
              Reviews below are written by registered Tennis Legacy players and published only after administrator approval.
            </p>
          </div>

          <button type="button" className="tlg-player-review-add" onClick={openReviewForm}>
            <Quote size={17} />
            {actionLabel}
          </button>
        </div>

        {notice && (
          <div className="tlg-player-review-notice">
            {myReview?.status === 'pending' ? <Clock3 size={17} /> : <CheckCircle2 size={17} />}
            <span>{notice}</span>
          </div>
        )}

        <div className="tlg-player-reviews-shell">
          <button
            type="button"
            className="tlg-player-review-arrow tlg-player-review-arrow-left"
            onClick={() => scroll(-1)}
            aria-label="Previous reviews"
            disabled={reviews.length <= 3}
          >
            <ChevronLeft size={20} />
          </button>

          <div ref={trackRef} className="tlg-player-reviews-track">
            {reviewsLoading && (
              <div className="tlg-player-reviews-empty">Loading player reviews…</div>
            )}

            {!reviewsLoading && reviews.length === 0 && (
              <div className="tlg-player-reviews-empty">
                No approved player reviews yet. Be the first player to send one for approval.
              </div>
            )}

            {reviews.map((review) => (
              <article className="tlg-player-review-card" key={review.id}>
                <div className="tlg-player-review-card-top">
                  <Quote size={24} />
                  <div className="tlg-player-review-stars" aria-label={String(review.rating) + ' out of 5 stars'}>
                    {Array.from({ length: 5 }, (_, index) => (
                      <Star
                        key={index}
                        size={15}
                        fill={index < review.rating ? 'currentColor' : 'none'}
                      />
                    ))}
                  </div>
                </div>

                <p>“{review.review_text}”</p>

                <footer>
                  <span className="tlg-player-review-flag">{flagForCountry(review.country_code)}</span>
                  <div>
                    <strong>{review.player_name}</strong>
                    <small>{review.world} player · {review.country_code}</small>
                  </div>
                </footer>
              </article>
            ))}
          </div>

          <button
            type="button"
            className="tlg-player-review-arrow tlg-player-review-arrow-right"
            onClick={() => scroll(1)}
            aria-label="Next reviews"
            disabled={reviews.length <= 3}
          >
            <ChevronRight size={20} />
          </button>
        </div>
      </div>

      {modalOpen && (
        <div className="tlg-player-review-modal-backdrop" role="presentation">
          <div className="tlg-player-review-modal" role="dialog" aria-modal="true" aria-labelledby="add-review-title">
            <button
              type="button"
              className="tlg-player-review-modal-close"
              onClick={() => setModalOpen(false)}
              aria-label="Close review form"
            >
              <X size={19} />
            </button>

            <span className="tlg-section-eyebrow">Player Review</span>
            <h3 id="add-review-title">
              {myReview?.status === 'rejected' ? 'Edit and resubmit your review' : 'Share your Tennis Legacy experience'}
            </h3>
            <p>
              Your review will not be public immediately. An administrator will review it first and can approve or reject it.
            </p>

            <form onSubmit={submitReview}>
              <label>Rating</label>
              <div className="tlg-player-review-rating">
                {Array.from({ length: 5 }, (_, index) => {
                  const value = index + 1
                  return (
                    <button
                      key={value}
                      type="button"
                      onClick={() => setRating(value)}
                      aria-label={'Rate ' + value + ' out of 5'}
                      className={value <= rating ? 'is-active' : undefined}
                    >
                      <Star size={24} fill={value <= rating ? 'currentColor' : 'none'} />
                    </button>
                  )
                })}
              </div>

              <label htmlFor="player-review-text">Your review</label>
              <textarea
                id="player-review-text"
                value={reviewText}
                onChange={(event) => setReviewText(event.target.value)}
                maxLength={700}
                rows={7}
                placeholder="Tell other players what you like about the game, your career experience, or what makes Tennis Legacy enjoyable for you."
                required
              />
              <div className="tlg-player-review-character-count">{reviewText.trim().length}/700</div>

              {formError && <div className="tlg-player-review-form-error">{formError}</div>}

              <button type="submit" className="tlg-player-review-submit" disabled={submitting}>
                <Send size={16} />
                {submitting ? 'Sending…' : 'Send Review for Approval'}
              </button>
            </form>
          </div>
        </div>
      )}
    </section>
  )
}
