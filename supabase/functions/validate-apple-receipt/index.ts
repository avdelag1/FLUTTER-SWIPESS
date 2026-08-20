import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const PROD_URL = 'https://buy.itunes.apple.com/verifyReceipt'
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt'

const SUBSCRIPTIONS: Record<string, string> = {
  'Swipess.plus.monthly.v3': 'Basic Client',
  'Swipess.plus.semestral.v3': 'Premium Client',
  'Swipess.plus.annual.v3': 'Unlimited Client',
}

const TOKENS: Record<string, number> = {
  'Swipess.tokens.20.v2': 20,
  'Swipess.tokens.50.v2': 50,
  'Swipess.tokens.100.v2': 100,
  'Swipess.tokens.150.v2': 150,
}

const EVENT_PROMOS = new Set([
  'Swipess.promo.event.week.v3',
  'Swipess.promo.event.month.v3',
  'Swipess.promo.event.quarter.v3',
])

const headers = { 'Content-Type': 'application/json' }

async function verifyReceipt(receipt: string, sharedSecret: string) {
  const body = JSON.stringify({
    'receipt-data': receipt,
    password: sharedSecret,
    'exclude-old-transactions': true,
  })

  let response = await fetch(PROD_URL, { method: 'POST', body })
  let data = await response.json()
  if (data.status === 21007) {
    response = await fetch(SANDBOX_URL, { method: 'POST', body })
    data = await response.json()
    data.environment = 'Sandbox'
  }
  return data
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ ok: false, error: 'Method not allowed' }), {
      status: 405,
      headers,
    })
  }

  const auth = req.headers.get('Authorization') ?? ''
  const url = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const sharedSecret = Deno.env.get('APPLE_SHARED_SECRET')

  if (!sharedSecret) {
    return new Response(JSON.stringify({ ok: false, error: 'Apple validation is not configured' }), {
      status: 500,
      headers,
    })
  }

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: auth } },
  })
  const { data: userData, error: userError } = await userClient.auth.getUser()
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), {
      status: 401,
      headers,
    })
  }

  try {
    const { receipt, productId, transactionId, submissionId } = await req.json()
    if (!receipt || !productId) {
      return new Response(JSON.stringify({ ok: false, error: 'Missing receipt or productId' }), {
        status: 400,
        headers,
      })
    }

    const isEventPromo = EVENT_PROMOS.has(productId)
    const knownProduct = productId in SUBSCRIPTIONS || productId in TOKENS || isEventPromo
    if (!knownProduct) {
      return new Response(JSON.stringify({ ok: false, error: 'Unknown product' }), {
        status: 400,
        headers,
      })
    }
    if (isEventPromo && !submissionId) {
      return new Response(
        JSON.stringify({ ok: false, error: 'Approved promotion submission is required' }),
        { status: 400, headers },
      )
    }

    const verified = await verifyReceipt(receipt, sharedSecret)
    if (verified.status !== 0) {
      return new Response(JSON.stringify({ ok: false, error: `Apple status ${verified.status}` }), {
        status: 400,
        headers,
      })
    }

    const transactions = [
      ...(verified.latest_receipt_info ?? []),
      ...(verified.receipt?.in_app ?? []),
    ]
    const tx = transactions
      .filter((item: any) => item.product_id === productId)
      .sort((a: any, b: any) => Number(b.purchase_date_ms ?? 0) - Number(a.purchase_date_ms ?? 0))[0]

    if (!tx) {
      return new Response(JSON.stringify({ ok: false, error: 'Transaction not found in receipt' }), {
        status: 400,
        headers,
      })
    }

    const txKey = tx.transaction_id ?? transactionId ?? tx.original_transaction_id
    if (!txKey) {
      return new Response(JSON.stringify({ ok: false, error: 'Missing transaction identifier' }), {
        status: 400,
        headers,
      })
    }

    const admin = createClient(url, serviceKey)
    const userId = userData.user.id

    const { data: audit, error: auditError } = await admin
      .from('purchase_audit_log')
      .insert({
        user_id: userId,
        product_id: productId,
        purchase_token: txKey,
        order_id: tx.transaction_id ?? transactionId ?? null,
        action: 'apple_iap_grant',
        source: 'apple',
        verified: true,
        metadata: {
          status: 'processing',
          environment: verified.environment ?? 'Production',
          ...(submissionId ? { submissionId } : {}),
        },
      })
      .select('id')
      .single()

    if (auditError) {
      if (auditError.code === '23505') {
        if (isEventPromo) {
          const { data: existing } = await admin
            .from('business_promo_submissions')
            .select('id, status, payment_transaction_id')
            .eq('id', submissionId)
            .eq('user_id', userId)
            .maybeSingle()
          const alreadyFinalized =
            existing &&
            (existing.status === 'paid' || existing.status === 'live') &&
            existing.payment_transaction_id === txKey
          if (!alreadyFinalized) {
            return new Response(
              JSON.stringify({ ok: false, error: 'Apple transaction was already used' }),
              { status: 409, headers },
            )
          }
        }
        return new Response(JSON.stringify({ ok: true, alreadyProcessed: true, productId }), {
          status: 200,
          headers,
        })
      }
      throw auditError
    }

    try {
      if (productId in SUBSCRIPTIONS) {
        const packageName = SUBSCRIPTIONS[productId]
        const { data: pkg, error: pkgError } = await admin
          .from('subscription_packages')
          .select('id')
          .eq('name', packageName)
          .eq('is_active', true)
          .maybeSingle()
        if (pkgError || !pkg) throw new Error(`Subscription package unavailable: ${packageName}`)

        const purchaseDate = tx.purchase_date_ms
          ? new Date(Number(tx.purchase_date_ms)).toISOString()
          : new Date().toISOString()
        const expiresDate = tx.expires_date_ms
          ? new Date(Number(tx.expires_date_ms)).toISOString()
          : null

        await admin
          .from('user_subscriptions')
          .update({ is_active: false, end_date: new Date().toISOString() })
          .eq('user_id', userId)
          .eq('is_active', true)

        const { error: subError } = await admin.from('user_subscriptions').upsert({
          user_id: userId,
          package_id: pkg.id,
          start_date: purchaseDate,
          end_date: expiresDate,
          is_active: expiresDate ? new Date(expiresDate) > new Date() : true,
          payment_status: 'paid',
          transaction_id: tx.transaction_id ?? transactionId ?? txKey,
        }, { onConflict: 'user_id,package_id' })
        if (subError) throw subError
      } else if (productId in TOKENS) {
        const amount = TOKENS[productId]
        const { error: tokenError } = await admin.from('tokens').insert({
          user_id: userId,
          token_type: 'messages',
          amount,
          total_activations: amount,
          remaining_activations: amount,
          used_activations: 0,
          activation_type: 'purchase',
          source: 'apple_iap',
          notes: `Apple IAP: ${productId}`,
        })
        if (tokenError) throw tokenError
      } else if (isEventPromo) {
        const { error: promoError } = await admin.rpc('finalize_event_promo_purchase', {
          p_user_id: userId,
          p_submission_id: submissionId,
          p_product_id: productId,
          p_transaction_id: txKey,
        })
        if (promoError) throw promoError
      }

      await admin
        .from('purchase_audit_log')
        .update({
          metadata: {
            status: 'granted',
            environment: verified.environment ?? 'Production',
            productId,
            ...(submissionId ? { submissionId } : {}),
          },
        })
        .eq('id', audit.id)

      return new Response(JSON.stringify({ ok: true, productId }), { status: 200, headers })
    } catch (grantError) {
      await admin.from('purchase_audit_log').delete().eq('id', audit.id)
      throw grantError
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    return new Response(JSON.stringify({ ok: false, error: message }), {
      status: 500,
      headers,
    })
  }
})