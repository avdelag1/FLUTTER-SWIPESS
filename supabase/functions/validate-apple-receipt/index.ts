import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const APPLE_SECRET = Deno.env.get('APPLE_SHARED_SECRET')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')

serve(async (req) => {
  const { productId, transactionId, receipt } = await req.json()

  // Prepare Apple API request
  const requestBody = JSON.stringify({
    'receipt-data': receipt,
    password: APPLE_SECRET,
  })

  // 1. Try production first
  let appleResponse = await fetch('https://buy.itunes.apple.com/verifyReceipt', {
    method: 'POST',
    body: requestBody,
  })
  let appleData = await appleResponse.json()

  // 2. If it's a sandbox receipt (21007), try sandbox
  if (appleData.status === 21007) {
    appleResponse = await fetch('https://sandbox.itunes.apple.com/verifyReceipt', {
      method: 'POST',
      body: requestBody,
    })
    appleData = await appleResponse.json()
  }

  // 3. Verify success
  if (appleData.status !== 0) {
    return new Response(JSON.stringify({ ok: false, error: 'Invalid receipt' }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // 4. Update the user's subscription in Supabase
  const authHeader = req.headers.get('Authorization')!
  const supabase = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: authHeader } },
  })
  
  const { data: { user }, error: userError } = await supabase.auth.getUser()
  if (userError || !user) {
    return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Define your products here
  let newTier = 'free'
  let addTokens = 0

  if (productId === 'swipess_package_1') {
    newTier = 'package1'
    addTokens = 15
  } else if (productId === 'swipess_package_2') {
    newTier = 'package2'
    addTokens = 25
  } else if (productId === 'swipess_premium') {
    newTier = 'premium'
    addTokens = 9999
  } else if (productId === 'swipess_tokens_5') {
    addTokens = 5
  }

  // Fetch current user subscriptions
  const { data: currentSub } = await supabase
    .from('user_subscriptions')
    .select('*')
    .eq('user_id', user.id)
    .single()

  const currentTokens = currentSub?.tokens_balance ?? 0

  // Upsert subscription logic
  await supabase.from('user_subscriptions').upsert({
    user_id: user.id,
    subscription_tier: newTier !== 'free' ? newTier : (currentSub?.subscription_tier ?? 'free'),
    tokens_balance: currentTokens + addTokens,
    updated_at: new Date().toISOString(),
  })

  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
