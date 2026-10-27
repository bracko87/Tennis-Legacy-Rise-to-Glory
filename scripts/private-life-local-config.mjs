/**
 * Supabase CLI "supabase status -o env" contains both public and privileged
 * keys. Select only the local browser-safe public key. Never print input.
 */
export function parsePrivateLifeLocalStatus(output) {
  const values = new Map();
  for (const line of String(output ?? '').split(/\r?\n/)) {
    const match = line.trim().match(/^(?:export\s+)?([A-Z][A-Z0-9_]*)=(.*)$/);
    if (!match) continue;
    let val = match[2].trim();
    if ((val.startsWith('"') && val.endsWith('"')) ||
        (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    values.set(match[1], val);
  }
  const rawUrl = values.get('API_URL') ?? values.get('SUPABASE_URL') ?? '';
  let url;
  try { url = new URL(rawUrl); } catch {
    throw new Error('Local Supabase status did not provide a valid API_URL.');
  }
  if (url.protocol !== 'http:' ||
      !['127.0.0.1', 'localhost'].includes(url.hostname) ||
      url.port !== '54331' || url.username || url.password ||
      url.pathname !== '/' || url.search || url.hash) {
    throw new Error('Refusing a non-sandbox backend: expected http://127.0.0.1:54331.');
  }
  const key = values.get('PUBLISHABLE_KEY') ??
    values.get('SUPABASE_PUBLISHABLE_KEY') ??
    values.get('ANON_KEY') ?? '';
  if (!(key.startsWith('sb_publishable_') || key.startsWith('eyJ')) ||
      key.length < 25 || /\s/.test(key)) {
    throw new Error('No browser-safe local publishable/ANON_KEY found. Never use SERVICE_ROLE_KEY.');
  }
  return { url: url.origin, publishableKey: key };
}
