/** Only a conflicting portrait reservation should clear the chosen portrait. */
export function isPortraitReservationConflict(error: {
  code?: string | null
  message?: string | null
}): boolean {
  return error.code === '23505' &&
    /player_avatar_reservations_(?:pkey|player_id_key)/i.test(error.message ?? '')
}
