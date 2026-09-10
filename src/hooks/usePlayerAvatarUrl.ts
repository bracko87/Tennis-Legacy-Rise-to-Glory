import { useEffect, useState } from 'react'

import { supabase } from '../lib/supabase'

const CATALOG_PREFIXES = ['ATP Avatars/', 'WTA Avatars/', 'ATP AI Profils/'] as const

function getAvatarBucket(imagePath: string) {
  return CATALOG_PREFIXES.some((prefix) => imagePath.startsWith(prefix))
    ? 'Admin'
    : 'player-avatars'
}

/**
 * Resolve a player's stored image path to a browser-safe URL.
 *
 * Curated ATP/WTA portraits live in the private Admin bucket and therefore
 * require authenticated signed URLs. User-approved avatars live in the public
 * player-avatars bucket, so they must use the bucket's public URL instead of
 * requesting a signed URL that can fail when no object SELECT policy exists.
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

    const resolvedImagePath = imagePath

    async function resolveAvatar() {
      const bucket = getAvatarBucket(resolvedImagePath)

      if (bucket === 'player-avatars') {
        const { data } = supabase.storage
          .from(bucket)
          .getPublicUrl(resolvedImagePath)

        if (active) setAvatarUrl(data.publicUrl)
        return
      }

      const { data, error } = await supabase.storage
        .from(bucket)
        .createSignedUrl(resolvedImagePath, 3600)

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
