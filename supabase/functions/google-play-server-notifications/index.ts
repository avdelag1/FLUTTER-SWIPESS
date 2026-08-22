import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const PACKAGE_NAME = 'com.swipess.mobile';
const SUBSCRIPTIONS: Record<string, string> = {
  'swipess.plus.monthly.v2': 'Basic Client',
  'swipess.plus.semestral.v2': 'Premium Client',
  'swipess.plus.annual.v2': 'Unlimited Client',
};

function response(status = 204, body = '') {
  return new Response(body, {
    status,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
  });
}

function base64Url(value: string): string {
  return btoa(value)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function googleAccessToken(): Promise<string> {
  const raw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON not configured');

  const serviceAccount = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(
    JSON.stringify({
      alg: 'RS256',
      typ: 'JWT',
      kid: serviceAccount.private_key_id,
    }),
  );
  const claims = base64Url(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: 'https://oauth2.googleapis.com/token',
      exp: now + 3600,
      iat: now,
    }),
  );
  const input = `${header}.${claims}`;
  const pemBody = String(serviceAccount.private_key)
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      new TextEncoder().encode(input),
    ),
  );
  let binary = '';
  for (const byte of signature) binary += String.fromCharCode(byte);
  const assertion = `${input}.${base64Url(binary)}`;

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!tokenResponse.ok) {
    throw new Error(`Google OAuth failed: ${tokenResponse.status}`);
  }
  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error('Google OAuth returned no access token');
  }
  return tokenData.access_token;
}

async function fetchSubscription(purchaseToken: string): Promise<any> {
  const accessToken = await googleAccessToken();
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(PACKAGE_NAME)}/purchases/subscriptionsv2/tokens/` +
    `${encodeURIComponent(purchaseToken)}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    throw new Error(
      `Google subscriptionsv2.get failed: ${res.status} ${await res.text()}`,
    );
  }
  return await res.json();
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return response(405, JSON.stringify({ error: 'Method not allowed' }));
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  let eventKey = '';
  try {
    const envelope = await req.json();
    const message = envelope?.message;
    if (!message?.data) {
      return response(
        400,
        JSON.stringify({ error: 'Missing Pub/Sub message data' }),
      );
    }

    const bytes = Uint8Array.from(atob(message.data), (c) => c.charCodeAt(0));
    const notification = JSON.parse(new TextDecoder().decode(bytes));
    if (notification.packageName !== PACKAGE_NAME) return response(204);

    const subscriptionNotification = notification.subscriptionNotification;
    const purchaseToken = subscriptionNotification?.purchaseToken ?? null;
    const notificationType = subscriptionNotification?.notificationType ?? null;
    const eventTimeMillis = Number(notification.eventTimeMillis || Date.now());
    eventKey =
      message.messageId ||
      `${purchaseToken ?? 'test'}:${notificationType ?? 'test'}:${eventTimeMillis}`;

    const { error: insertError } = await admin
      .from('google_play_server_notifications')
      .insert({
        event_key: eventKey,
        purchase_token: purchaseToken,
        notification_type: notificationType,
        package_name: notification.packageName,
        event_time: new Date(eventTimeMillis).toISOString(),
        raw: notification,
        status: notification.testNotification ? 'test' : 'processing',
      });

    if (insertError?.code === '23505') return response(204);
    if (insertError) throw insertError;

    if (notification.testNotification) {
      await admin
        .from('google_play_server_notifications')
        .update({ status: 'processed', processed_at: new Date().toISOString() })
        .eq('event_key', eventKey);
      return response(204);
    }

    if (!purchaseToken || notificationType == null) {
      await admin
        .from('google_play_server_notifications')
        .update({ status: 'ignored', processed_at: new Date().toISOString() })
        .eq('event_key', eventKey);
      return response(204);
    }

    const { data: transaction, error: txLookupError } = await admin
      .from('google_play_transactions')
      .select('user_id, product_id, purchase_token, order_id')
      .eq('purchase_token', purchaseToken)
      .maybeSingle();
    if (txLookupError) throw txLookupError;

    // A PURCHASED RTDN can race the app's first validation. The secure app
    // validator also queries subscriptionsv2, so retain the audit event and
    // acknowledge it rather than creating an entitlement without a user map.
    if (!transaction) {
      await admin
        .from('google_play_server_notifications')
        .update({ status: 'unmapped', processed_at: new Date().toISOString() })
        .eq('event_key', eventKey);
      return response(204);
    }

    const purchase = await fetchSubscription(purchaseToken);
    const lineItems = Array.isArray(purchase.lineItems) ? purchase.lineItems : [];
    const lineItem =
      lineItems.find((item: any) => SUBSCRIPTIONS[item.productId]) ?? lineItems[0];
    const productId = lineItem?.productId ?? transaction.product_id;
    const packageName = SUBSCRIPTIONS[productId];
    if (!packageName) {
      throw new Error(`Unknown subscription product: ${productId}`);
    }

    const { data: pkg, error: pkgError } = await admin
      .from('subscription_packages')
      .select('id')
      .eq('name', packageName)
      .eq('is_active', true)
      .maybeSingle();
    if (pkgError || !pkg) {
      throw new Error(`Subscription package unavailable: ${packageName}`);
    }

    const state = String(
      purchase.subscriptionState || 'SUBSCRIPTION_STATE_UNSPECIFIED',
    );
    const expiryTime = lineItem?.expiryTime
      ? new Date(lineItem.expiryTime)
      : null;
    const expiryFuture = !!expiryTime && expiryTime.getTime() > Date.now();
    const explicitlyRevoked = Number(notificationType) === 12;
    const explicitlyExpired =
      Number(notificationType) === 13 || state === 'SUBSCRIPTION_STATE_EXPIRED';
    const activeState = [
      'SUBSCRIPTION_STATE_ACTIVE',
      'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
      'SUBSCRIPTION_STATE_CANCELED',
    ].includes(state);

    const isActive =
      !explicitlyRevoked &&
      !explicitlyExpired &&
      activeState &&
      expiryFuture;

    let paymentStatus = 'paid';
    if (explicitlyRevoked) paymentStatus = 'revoked';
    else if (explicitlyExpired) paymentStatus = 'expired';
    else if (state === 'SUBSCRIPTION_STATE_ON_HOLD') paymentStatus = 'failed';
    else if (state === 'SUBSCRIPTION_STATE_PENDING') paymentStatus = 'pending';
    else if (!isActive && state === 'SUBSCRIPTION_STATE_PAUSED') {
      paymentStatus = 'cancelled';
    }

    const latestOrderId =
      lineItem?.latestSuccessfulOrderId || transaction.order_id || purchaseToken;
    const startDate = purchase.startTime
      ? new Date(purchase.startTime).toISOString()
      : new Date(eventTimeMillis).toISOString();

    const { error: subError } = await admin.from('user_subscriptions').upsert(
      {
        user_id: transaction.user_id,
        package_id: pkg.id,
        start_date: startDate,
        end_date: expiryTime?.toISOString() ?? null,
        is_active: isActive,
        payment_status: paymentStatus,
        transaction_id: latestOrderId,
        original_transaction_id: purchaseToken,
        store: 'google',
        store_environment: 'Production',
        store_signed_date: new Date(eventTimeMillis).toISOString(),
      },
      { onConflict: 'user_id,package_id' },
    );
    if (subError) throw subError;

    const { error: txError } = await admin
      .from('google_play_transactions')
      .update({
        product_id: productId,
        order_id: latestOrderId,
        raw: purchase,
        verified: true,
      })
      .eq('purchase_token', purchaseToken);
    if (txError) throw txError;

    await admin
      .from('google_play_server_notifications')
      .update({ status: 'processed', processed_at: new Date().toISOString() })
      .eq('event_key', eventKey);

    return response(204);
  } catch (error) {
    console.error('[google-play-server-notifications]', error);
    if (eventKey) {
      await admin
        .from('google_play_server_notifications')
        .update({ status: 'failed' })
        .eq('event_key', eventKey);
    }
    return response(
      500,
      JSON.stringify({ error: 'Notification processing failed' }),
    );
  }
});
