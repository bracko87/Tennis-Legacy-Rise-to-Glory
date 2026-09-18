export default async function analyticsGeo(_request: Request, context: any) {
  const countryCode = String(context?.geo?.country?.code ?? '').toUpperCase()
  const safeCountryCode = /^[A-Z]{2}$/.test(countryCode) ? countryCode : null

  return new Response(JSON.stringify({ countryCode: safeCountryCode }), {
    status: 200,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'private, no-store, max-age=0',
    },
  })
}

export const config = {
  path: '/api/analytics-geo',
}
