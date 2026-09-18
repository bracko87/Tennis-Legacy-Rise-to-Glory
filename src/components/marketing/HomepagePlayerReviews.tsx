import { useEffect, useRef, useState } from 'react'
import {
  ChevronLeft,
  ChevronRight,
  Quote,
  Star,
} from 'lucide-react'
import { useNavigate } from 'react-router'

import { supabase } from '../../lib/supabase'

interface PublicReview {
  id: string
  player_name: string
  country_code: string | null
  world: 'ATP' | 'WTA' | null
  reviewer_type: 'player' | 'community'
  rating: number
  review_text: string
  approved_at: string | null
}

function flagForCountry(code: string | null) {
  const upper = String(code || '').toUpperCase()
  if (!/^[A-Z]{2}$/.test(upper)) return '🌐'
  return String.fromCodePoint(...upper.split('').map((char) => 127397 + char.charCodeAt(0)))
}

export default function HomepagePlayerReviews() {
  const navigate = useNavigate()
  const trackRef = useRef<HTMLDivElement | null>(null)
  const [reviews, setReviews] = useState<PublicReview[]>([])
  const [reviewsLoading, setReviewsLoading] = useState(true)

  useEffect(() => {
    let mounted = true

    async function loadPublicReviews() {
      setReviewsLoading(true)
      const { data, error } = await supabase.rpc('get_public_homepage_reviews_v1', { p_limit: 30 })

      if (!mounted) return

      if (error) {
        console.warn('Unable to load homepage reviews:', error.message)
        setReviews([])
      } else {
        setReviews((data ?? []) as PublicReview[])
      }

      setReviewsLoading(false)
    }

    void loadPublicReviews()

    return () => {
      mounted = false
    }
  }, [])

  function scroll(direction: -1 | 1) {
    const node = trackRef.current
    if (!node) return

    node.scrollBy({
      left: direction * Math.max(280, node.clientWidth * 0.86),
      behavior: 'smooth',
    })
  }

  return (
    <section className="tlg-player-reviews-section" aria-labelledby="player-reviews-title">
      <div className="tlg-section">
        <div className="tlg-player-reviews-heading">
          <div>
            <span className="tlg-section-eyebrow">Player Reviews</span>
            <h2 id="player-reviews-title" className="tlg-section-title">What people say about Tennis Legacy</h2>
            <p className="tlg-section-description">
              Reviews can be submitted by players and visitors. Every review is checked by an administrator before it appears here.
            </p>
          </div>

          <button
            type="button"
            className="tlg-player-review-add"
            onClick={() => navigate('/reviews/add')}
          >
            <Quote size={17} />
            Add Review
          </button>
        </div>

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
              <div className="tlg-player-reviews-empty">Loading reviews…</div>
            )}

            {!reviewsLoading && reviews.length === 0 && (
              <div className="tlg-player-reviews-empty">
                No approved reviews yet. Be the first person to send one for approval.
              </div>
            )}

            {reviews.map((review) => {
              const reviewerLabel =
                review.reviewer_type === 'player' && review.world
                  ? review.world + ' player'
                  : 'Community reviewer'

              return (
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
                      <small>
                        {reviewerLabel}
                        {review.country_code ? ' · ' + review.country_code : ''}
                      </small>
                    </div>
                  </footer>
                </article>
              )
            })}
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
    </section>
  )
}
