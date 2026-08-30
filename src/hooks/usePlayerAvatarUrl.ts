import { useEffect, useState } from 'react'

import { supabase } from '../lib/supabase'

const CATALOG_PREFIXES = ['ATP Avatars/', 'WTA Avatars/'] as const

function getAvatarBucket(imagePath: string) {
  return CATALOG_PREFIXES.some((prefix) => imagePath.startsWith(prefix))
    ? 'Admin'
    : 'player-avatars'
}

/**
 * Resolve a player's stored image path to an authenticated signed URL.
 *
 * Curated ATP/WTA portraits live in the private Admin bucket, while future
 * custom player uploads may live in player-avatars. Keeping this logic here
 * prevents dashboard pages from accidentally constructing public URLs for a
 * private bucket.
 */
export default function usePlayerAvatarUrl(imagePath?: string | null) {
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null)

  useEffect(() => {
    let active = true
    setAvatarUrl(null)

    if (!imagePath) {
      return () => {
        active = false
      }
    }

    async function resolveAvatar() {
      const bucket = getAvatarBucket(imagePath)
      const { data, error } = await supabase.storage
        .from(bucket)
        .createSignedUrl(imagePath, 3600)

      if (!active) return

      if (error) {
        console.error(`Unable to load Tennis Legacy player portrait from ${bucket}:`, error.message)
        setAvatarUrl(null)
        return
      }

      setAvatarUrl(data.signedUrl)
    }

    void resolveAvatar()

    return () => {
      active = false
    }
  }, [imagePath])

  return avatarUrl
}
