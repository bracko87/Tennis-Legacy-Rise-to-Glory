declare const __TL_ACE_REVIEW__: boolean
// Only the isolated build script can enable this. No runtime/localStorage override.
export const aceReviewEnabled = typeof __TL_ACE_REVIEW__ !== 'undefined' && __TL_ACE_REVIEW__ === true
