import { useEffect, useState } from 'react'
import {
  Check,
  Clock3,
  RefreshCw,
  Star,
  X,
} from 'lucide-react'

import GameLayout from '../../components/layout/GameLayout'
import { supabase } from '../../lib/supabase'

type ReviewStatus = 'pending' | 'approved' | 'rejected'
type ReviewFilter = ReviewStatus | 'all'

interface AdminReview {
  id: string
  player_id: string
  player_name: string
  country_code: string
  world: 'ATP' | 'WTA'
  rating: number
  review_text: string
  status: ReviewStatus
  submitted_at: string
  reviewed_at: string | null
}

const FILTERS: Array<{ value: ReviewFilter; label: string }> = [
  { value: 'pending', label: 'Pending' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'all', label: 'All' },
]

function flagForCountry(code: string) {
  const upper = String(code || '').toUpperCase()
  if (!/^[A-Z]{2}$/.test(upper)) return '🌐'
  return String.fromCodePoint(...upper.split('').map((char) => 127397 + char.charCodeAt(0)))
}

function formatDate(value: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return new Intl.DateTimeFormat('en', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date)
}

export default function AdminReviewsPage() {
  const [filter, setFilter] = useState<ReviewFilter>('pending')
  const [reviews, setReviews] = useState<AdminReview[]>([])
  const [loading, setLoading] = useState(true)
  const [moderatingId, setModeratingId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  async function loadReviews(nextFilter = filter) {
    setLoading(true)
    setError(null)
    const { data, error: rpcError } = await supabase.rpc('get_admin_homepage_reviews_v1', {
      p_status: nextFilter,
    })

    if (rpcError) {
      setReviews([])
      setError(rpcError.message)
    } else {
      setReviews((data ?? []) as AdminReview[])
    }
    setLoading(false)
  }

  useEffect(() => {
    void loadReviews(filter)
  }, [filter])

  async function moderate(reviewId: string, decision: 'approved' | 'rejected') {
    setModeratingId(reviewId)
    setError(null)

    const { error: rpcError } = await supabase.rpc('moderate_homepage_review_v1', {
      p_review_id: reviewId,
      p_decision: decision,
    })

    setModeratingId(null)

    if (rpcError) {
      setError(rpcError.message)
      return
    }

    window.dispatchEvent(new Event('tlg-admin-notifications-refresh'))
    await loadReviews(filter)
  }

  return (
    <GameLayout title="Player Reviews" subtitle="Approve or reject reviews submitted for the public homepage">
      <div className="tlg-admin-reviews">
        <div className="tlg-admin-reviews-toolbar">
          <div className="tlg-admin-review-tabs" role="tablist" aria-label="Review status">
            {FILTERS.map((option) => (
              <button
                type="button"
                key={option.value}
                className={filter === option.value ? 'is-active' : undefined}
                onClick={() => setFilter(option.value)}
              >
                {option.label}
              </button>
            ))}
          </div>

          <button type="button" className="tlg-admin-review-refresh" onClick={() => void loadReviews()} disabled={loading}>
            <RefreshCw size={15} className={loading ? 'is-spinning' : undefined} />
            Refresh
          </button>
        </div>

        {error && <div className="tlg-admin-review-error">{error}</div>}

        {loading ? (
          <div className="tlg-admin-review-empty">Loading review requests…</div>
        ) : reviews.length === 0 ? (
          <div className="tlg-admin-review-empty">
            {filter === 'pending' ? 'There are no player reviews waiting for approval.' : 'No reviews found for this filter.'}
          </div>
        ) : (
          <div className="tlg-admin-review-list">
            {reviews.map((review) => (
              <article key={review.id} className="tlg-admin-review-card">
                <header>
                  <div className="tlg-admin-review-player">
                    <span>{flagForCountry(review.country_code)}</span>
                    <div>
                      <strong>{review.player_name}</strong>
                      <small>{review.world} · {review.country_code}</small>
                    </div>
                  </div>

                  <span className={'tlg-admin-review-status is-' + review.status}>
                    {review.status === 'pending' && <Clock3 size={13} />}
                    {review.status}
                  </span>
                </header>

                <div className="tlg-admin-review-stars" aria-label={String(review.rating) + ' out of 5 stars'}>
                  {Array.from({ length: 5 }, (_, index) => (
                    <Star key={index} size={16} fill={index < review.rating ? 'currentColor' : 'none'} />
                  ))}
                </div>

                <blockquote>{review.review_text}</blockquote>

                <div className="tlg-admin-review-meta">
                  <span>Submitted: {formatDate(review.submitted_at)}</span>
                  {review.reviewed_at && <span>Last moderated: {formatDate(review.reviewed_at)}</span>}
                </div>

                <footer>
                  {review.status !== 'approved' && (
                    <button
                      type="button"
                      className="approve"
                      disabled={moderatingId === review.id}
                      onClick={() => void moderate(review.id, 'approved')}
                    >
                      <Check size={15} />
                      Approve & Publish
                    </button>
                  )}
                  {review.status !== 'rejected' && (
                    <button
                      type="button"
                      className="reject"
                      disabled={moderatingId === review.id}
                      onClick={() => void moderate(review.id, 'rejected')}
                    >
                      <X size={15} />
                      Reject
                    </button>
                  )}
                </footer>
              </article>
            ))}
          </div>
        )}
      </div>
    </GameLayout>
  )
}
