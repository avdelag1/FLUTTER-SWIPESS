import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

// Native Sign in with Apple is completed in Flutter/Supabase using the identity
// token. This endpoint only receives Apple's one-time authorization code for a
// possible future server-side token exchange. Never log that sensitive code.
serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ ok: false, error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { authorizationCode } = await req.json().catch(() => ({}))
  if (!authorizationCode || typeof authorizationCode !== 'string') {
    return new Response(JSON.stringify({ ok: false, error: 'Missing code' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
