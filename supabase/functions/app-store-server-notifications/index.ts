import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'
import {
  Environment,
  SignedDataVerifier,
} from 'npm:@apple/app-store-server-library@3.1.0'
import { Buffer } from 'node:buffer'

const BUNDLE_ID = 'com.swipess.mobile'
const APP_APPLE_ID = 6779810584

const SUBSCRIPTIONS: Record<string, string> = {
  'Swipess.plus.monthly.v3': 'Basic Client',
  'Swipess.plus.semestral.v3': 'Premium Client',
  'Swipess.plus.annual.v3': 'Unlimited Client',
}

const APPLE_ROOT_URLS = [
  'https://www.apple.com/appleca/AppleIncRootCertificate.cer',
  'https://www.apple.com/certificateauthority/AppleRootCA-G2.cer',
  'https://www.apple.com/certificateauthority/AppleRootCA-G3.cer',
]

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const jsonHeaders = { 'Content-Type': 'application/json' }

let rootsPromise: Promise<Buffer[]> | null = null
const verifierCache = new Map<string, SignedDataVerifier>()

function asUuid(value: unknown): string | null {
  const text = typeof value === 'string' ? value.trim() : ''
  return uuidPattern.test(text) ? text.toLowerCase() : null
}

function toIso(ms: unknown): string | null {
  if (typeof ms !== 'number' || !Number.isFinite(ms) || ms <= 0) return null
  return new Date(ms).toISOString()
}

function decodeUnverifiedPayload(signedPayload: string): Record<string, unknown> {
  const parts = signedPayload.split('.')
  if (parts.length !== 3) throw new Error('Malformed signedPayload')
  let payload = parts[1].replace(/-/g, '+').replace(/_/g, '/')
  payload += '='.repeat((4 - (payload.length % 4)) % 4)
  return JSON.parse(atob(payload)) as Record<string, unknown>
}

async function appleRoots(): Promise<Buffer[]> {
  if (!rootsPromise) {
    rootsPromise = Promise.all(
      APPLE_ROOT_URLS.map(async (url) => {
        const response = await fetch(url)
        if (!response.ok) throw new Error(`Apple root certificate unavailable: ${response.status}`)
        return Buffer.from(await response.arrayBuffer())
      }),
    ).catch((error) => {
      rootsPromise = null
      throw error
    })
  }
  return rootsPromise
}

async function verifierFor(environmentText: string): Promise<SignedDataVerifier> {
  const isSandbox = environmentText.toLowerCase() === 'sandbox'
  const key = isSandbox ? 'sandbox' : 'production'
  const cached = verifierCache.get(key)
  if (cached) return cached

  const verifier = new SignedDataVerifier(
    await appleRoots(),
    true,
    isSandbox ? Environment.SANDBOX : Environment.PRODUCTION,
    BUNDLE_ID,
    isSandbox ? undefined : APP_APPLE_ID,
  )
  verifierCache.set(key, verifier)
  return verifier
}

async function markNotification(
  admin: ReturnType<typeof createClient>,
  notificationUuid: string,
  values: Record<string, unknown>,
) {
  const { error } = await admin
    .from('app_store_server_notifications')
    .update({ ...values, updated_at: new Date().toISOString() })
    .eq('notification_uuid', notificationUuid)
  if (error) throw error
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ ok: false, error: 'Method not allowed' }), {
      status: 405,
      headers: jsonHeaders,
    })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRole) {
    return new Response(JSON.stringify({ ok: false, error: 'Server configuration unavailable' }), {
      status: 500,
      headers: jsonHeaders,
    })
  }
  const admin = createClient(supabaseUrl, serviceRole)

  let notificationUuid: string | null = null
  try {
    const body = await req.json()
    const signedPayload = typeof body?.signedPayload === 'string' ? body.signedPayload : ''
    if (!signedPayload) {
      return new Response(JSON.stringify({ ok: false, error: 'Missing signedPayload' }), {
        status: 400,
        headers: jsonHeaders,
      })
    }

    // This decode is used only to choose the sandbox/production verifier. No
    // entitlement or database mutation is based on this unverified content.
    const claimed = decodeUnverifiedPayload(signedPayload)
    const claimedData = claimed.data as Record<string, unknown> | undefined
    const claimedEnvironment = String(claimedData?.environment ?? 'Production')

    const verifier = await verifierFor(claimedEnvironment)
    const notification = await verifier.verifyAndDecodeNotification(signedPayload)

    notificationUuid = notification.notificationUUID ?? null
    const notificationType = String(notification.notificationType ?? 'UNKNOWN')
    const subtype = notification.subtype == null ? null : String(notification.subtype)
    const signedDateIso = toIso(notification.signedDate)
    const data = notification.data
    const environment = String(data?.environment ?? claimedEnvironment)

    if (!notificationUuid) throw new Error('Verified notification is missing notificationUUID')

    const { data: existing, error: existingError } = await admin
      .from('app_store_server_notifications')
      .select('status')
      .eq('notification_uuid', notificationUuid)
      .maybeSingle()
    if (existingError) throw existingError
    if (existing?.status === 'processed' || existing?.status === 'ignored') {
      return new Response(JSON.stringify({ ok: true, duplicate: true }), {
        status: 200,
        headers: jsonHeaders,
      })
    }

    const baseLedger = {
      notification_uuid: notificationUuid,
      notification_type: notificationType,
      subtype,
      signed_date: signedDateIso,
      environment,
      status: 'processing',
      error_message: null,
      metadata: { version: notification.version ?? '2.0' },
      updated_at: new Date().toISOString(),
    }
    const { error: ledgerError } = await admin
      .from('app_store_server_notifications')
      .upsert(baseLedger, { onConflict: 'notification_uuid' })
    if (ledgerError) throw ledgerError

    // TEST and notification families without transaction data are valid Apple
    // notifications but do not mutate marketplace subscription entitlements.
    if (!data?.signedTransactionInfo) {
      await markNotification(admin, notificationUuid, {
        status: 'ignored',
        processed_at: new Date().toISOString(),
        metadata: { reason: 'no_subscription_transaction' },
      })
      return new Response(JSON.stringify({ ok: true, ignored: true }), {
        status: 200,
        headers: jsonHeaders,
      })
    }

    const transaction = await verifier.verifyAndDecodeTransaction(data.signedTransactionInfo)
    const renewal = data.signedRenewalInfo
      ? await verifier.verifyAndDecodeRenewalInfo(data.signedRenewalInfo)
      : null

    const productId = transaction.productId ?? renewal?.productId ?? renewal?.autoRenewProductId
    const transactionId = transaction.transactionId ?? null
    const originalTransactionId =
      transaction.originalTransactionId ?? renewal?.originalTransactionId ?? null
    const appAccountToken =
      asUuid(transaction.appAccountToken) ?? asUuid(renewal?.appAccountToken)

    if (!productId || !(productId in SUBSCRIPTIONS)) {
      await markNotification(admin, notificationUuid, {
        status: 'ignored',
        processed_at: new Date().toISOString(),
        product_id: productId ?? null,
        transaction_id: transactionId,
        original_transaction_id: originalTransactionId,
        metadata: { reason: 'non_subscription_product' },
      })
      return new Response(JSON.stringify({ ok: true, ignored: true }), {
        status: 200,
        headers: jsonHeaders,
      })
    }

    let userId: string | null = appAccountToken
    if (userId) {
      const { data: authUser, error: authLookupError } = await admin.auth.admin.getUserById(userId)
      if (authLookupError || !authUser.user) userId = null
    }

    if (!userId && originalTransactionId) {
      const { data: mapped, error: mapError } = await admin
        .from('user_subscriptions')
        .select('user_id')
        .eq('original_transaction_id', originalTransactionId)
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (mapError) throw mapError
      userId = mapped?.user_id ?? null
    }

    if (!userId) {
      await markNotification(admin, notificationUuid, {
        status: 'error',
        error_message: 'Could not map verified Apple subscription to a Swipess user',
        product_id: productId,
        transaction_id: transactionId,
        original_transaction_id: originalTransactionId,
      })
      // A purchase validator may be racing the server notification. 500 asks
      // Apple to retry rather than silently losing the subscription lifecycle.
      return new Response(JSON.stringify({ ok: false, error: 'Subscription user mapping unavailable' }), {
        status: 500,
        headers: jsonHeaders,
      })
    }

    const packageName = SUBSCRIPTIONS[productId]
    const { data: pkg, error: packageError } = await admin
      .from('subscription_packages')
      .select('id')
      .eq('name', packageName)
      .eq('is_active', true)
      .maybeSingle()
    if (packageError || !pkg) throw packageError ?? new Error(`Subscription package unavailable: ${packageName}`)

    const { data: current, error: currentError } = await admin
      .from('user_subscriptions')
      .select('id,store_signed_date,transaction_id,package_id')
      .eq('user_id', userId)
      .eq('store', 'apple')
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (currentError) throw currentError

    const incomingSignedMs = notification.signedDate ?? 0
    const currentSignedMs = current?.store_signed_date
      ? new Date(current.store_signed_date).getTime()
      : 0
    if (incomingSignedMs > 0 && currentSignedMs > incomingSignedMs) {
      await markNotification(admin, notificationUuid, {
        status: 'ignored',
        processed_at: new Date().toISOString(),
        user_id: userId,
        product_id: productId,
        transaction_id: transactionId,
        original_transaction_id: originalTransactionId,
        metadata: { reason: 'stale_notification' },
      })
      return new Response(JSON.stringify({ ok: true, stale: true }), {
        status: 200,
        headers: jsonHeaders,
      })
    }

    const nowMs = Date.now()
    const expiresMs = transaction.expiresDate ?? 0
    const graceMs = renewal?.gracePeriodExpiresDate ?? 0
    const effectiveEndMs = Math.max(expiresMs, graceMs)
    const forcedInactive =
      transaction.revocationDate != null ||
      ['REFUND', 'REVOKE', 'EXPIRED', 'GRACE_PERIOD_EXPIRED'].includes(notificationType)
    const isActive = !forcedInactive && effectiveEndMs > nowMs
    const paymentStatus = isActive
      ? 'paid'
      : transaction.revocationDate != null || ['REFUND', 'REVOKE'].includes(notificationType)
        ? 'revoked'
        : 'expired'

    const startDate = toIso(transaction.purchaseDate ?? transaction.originalPurchaseDate) ?? new Date().toISOString()
    const endDate = toIso(effectiveEndMs) ?? new Date().toISOString()

    // Only one membership is active at a time. A plan change/renewal writes the
    // verified transaction first; the existing DB trigger grants 6/12/30 once
    // for each new paid transaction ID.
    if (isActive) {
      const { error: deactivateError } = await admin
        .from('user_subscriptions')
        .update({ is_active: false })
        .eq('user_id', userId)
        .eq('is_active', true)
        .neq('package_id', pkg.id)
      if (deactivateError) throw deactivateError
    }

    const subscriptionRow = {
      user_id: userId,
      package_id: pkg.id,
      start_date: startDate,
      end_date: endDate,
      is_active: isActive,
      payment_status: paymentStatus,
      transaction_id: transactionId ?? originalTransactionId,
      original_transaction_id: originalTransactionId,
      app_account_token: appAccountToken,
      store: 'apple',
      store_signed_date: signedDateIso,
      store_environment: environment,
    }
    const { error: subscriptionError } = await admin
      .from('user_subscriptions')
      .upsert(subscriptionRow, { onConflict: 'user_id,package_id' })
    if (subscriptionError) throw subscriptionError

    await markNotification(admin, notificationUuid, {
      status: 'processed',
      processed_at: new Date().toISOString(),
      error_message: null,
      user_id: userId,
      product_id: productId,
      transaction_id: transactionId,
      original_transaction_id: originalTransactionId,
      metadata: {
        active: isActive,
        payment_status: paymentStatus,
        effective_end: endDate,
        grace_period_applied: graceMs > expiresMs,
      },
    })

    return new Response(JSON.stringify({ ok: true, processed: true }), {
      status: 200,
      headers: jsonHeaders,
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    if (notificationUuid) {
      try {
        await markNotification(admin, notificationUuid, {
          status: 'error',
          error_message: message.slice(0, 1000),
        })
      } catch (_) {}
    }
    return new Response(JSON.stringify({ ok: false, error: 'Notification verification or processing failed' }), {
      status: 500,
      headers: jsonHeaders,
    })
  }
})
