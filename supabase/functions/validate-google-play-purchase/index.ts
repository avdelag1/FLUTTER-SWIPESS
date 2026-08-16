import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const ALLOWED_ORIGIN = '*';
const corsHeaders = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// TODO: Confirm these product IDs match the Google Play Console configuration.
const SUBSCRIPTIONS: Record<string, string> = {
  'swipess.plus.monthly.v2': 'Basic Client',
  'swipess.plus.semestral.v2': 'Premium Client',
  'swipess.plus.annual.v2': 'Unlimited Client',
};

const TOKENS: Record<string, number> = {
  'swipess.tokens.20.v1': 20,
  'swipess.tokens.50.v1': 50,
  'swipess.tokens.100.v1': 100,
  'swipess.tokens.150.v1': 150,
};

const EVENT_PROMOS = new Set([
  'swipess.promo.event.week.v2',
  'swipess.promo.event.month.v2',
  'swipess.promo.event.quarter.v2',
]);

interface GoogleVerifyResult {
  verified: boolean;
  orderId?: string;
  purchaseState?: number;
  startTimeMillis?: string;
  expiryTimeMillis?: string;
}

async function verifyWithGooglePlay(
  packageName: string,
  productId: string,
  purchaseToken: string,
  isSubscription: boolean,
): Promise<GoogleVerifyResult> {
  const googleServiceAccountJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
  if (!googleServiceAccountJson) {
    console.error("GOOGLE_SERVICE_ACCOUNT_JSON not configured; cannot verify purchase");
    return { verified: false };
  }

  try {
    const serviceAccount = JSON.parse(googleServiceAccountJson);
    const now = Math.floor(Date.now() / 1000);
    const jwtHeader = { alg: "RS256", typ: "JWT", kid: serviceAccount.private_key_id };
    const jwtBody = {
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/androidpublisher",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    };

    function base64url(s: string): string {
      return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    }

    const pemBody = String(serviceAccount.private_key)
      .replace(/-----BEGIN PRIVATE KEY-----/, "")
      .replace(/-----END PRIVATE KEY-----/, "")
      .replace(/\s+/g, "");
    const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

    const headerB64 = base64url(JSON.stringify(jwtHeader));
    const bodyB64 = base64url(JSON.stringify(jwtBody));
    const signatureInput = `${headerB64}.${bodyB64}`;

    const key = await crypto.subtle.importKey(
      "pkcs8",
      keyBytes,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(signatureInput),
    );
    const sigB64 = base64url(String.fromCharCode(...new Uint8Array(signature)));
    const jwt = `${signatureInput}.${sigB64}`;

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    const tokenData = await tokenRes.json();
    if (!tokenData.access_token) {
      console.error("Google OAuth token exchange failed", tokenData);
      return { verified: false };
    }

    const accessToken = tokenData.access_token;
    const kind = isSubscription ? "subscriptionsv2/tokens" : "products";
    const endpoint = isSubscription 
      ? `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`
      : `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;

    const verifyRes = await fetch(endpoint, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!verifyRes.ok) {
      console.error("Google Play API verification failed", verifyRes.status, await verifyRes.text());
      return { verified: false };
    }

    const result = await verifyRes.json();

    if (isSubscription) {
      const isActive = result.subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE' || 
                       result.subscriptionState === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ||
                       result.subscriptionState === 'SUBSCRIPTION_STATE_CANCELED';
      const lineItem = result.lineItems && result.lineItems.find((item: any) => item.productId === productId);
      if (!lineItem) {
        console.error(`Google Play API verification failed: no line item matches productId ${productId}`);
        return { verified: false };
      }
      const expiryTime = lineItem.expiryTime;
      const notExpired = !!expiryTime && new Date(expiryTime).getTime() > Date.now();
      
      return {
        verified: isActive && notExpired,
        orderId: lineItem.latestSuccessfulOrderId,
        startTimeMillis: result.startTime ? new Date(result.startTime).getTime().toString() : undefined,
        expiryTimeMillis: expiryTime ? new Date(expiryTime).getTime().toString() : undefined,
      };
    }

    // One-time product: purchaseState 0=purchased,1=cancelled,2=pending.
    return {
      verified: result.purchaseState === 0,
      orderId: result.orderId,
      purchaseState: result.purchaseState,
    };
  } catch (err) {
    console.error("Google Play verification error", err);
    return { verified: false };
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const auth = req.headers.get('Authorization') ?? '';
    // Service-role client for privileged DB writes (NO auth override)
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // User client for auth.getUser() only
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: auth } } }
    );
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const userId = userData.user.id;

    const { purchaseToken, productId, orderId: clientOrderId } = await req.json();
    if (!purchaseToken || !productId) {
      return new Response(JSON.stringify({ ok: false, error: 'Missing purchaseToken or productId' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const isSubscription = productId in SUBSCRIPTIONS;
    const isToken = productId in TOKENS;
    const isPromo = EVENT_PROMOS.has(productId);
    
    if (!isSubscription && !isToken && !isPromo) {
      return new Response(JSON.stringify({ ok: false, error: 'Unknown productId' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Server-side verification with the Google Play Developer API.
    const verification = await verifyWithGooglePlay('com.swipess.mobile', productId, purchaseToken, isSubscription);
    if (!verification.verified) {
      return new Response(JSON.stringify({ ok: false, error: 'Purchase could not be verified' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Reservation pattern matching apple validator
    const { data: audit, error: auditError } = await adminClient
      .from('purchase_audit_log')
      .insert({
        user_id: userId,
        product_id: productId,
        purchase_token: purchaseToken,
        order_id: clientOrderId || verification.orderId || null,
        action: 'google_play_grant',
        source: 'google',
        verified: true,
        metadata: {
          status: 'processing',
          environment: 'Production',
        },
      })
      .select('id')
      .single();

    if (auditError) {
      if (auditError.code === '23505') {
        const { data: existing } = await adminClient
          .from('purchase_audit_log')
          .select('user_id, product_id, metadata')
          .eq('purchase_token', purchaseToken)
          .single();
          
        if (existing && existing.user_id === userId && existing.product_id === productId) {
          if (existing.metadata?.status === 'granted') {
            return new Response(JSON.stringify({ ok: true, alreadyProcessed: true, productId }), {
              status: 200,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
          } else {
            return new Response(JSON.stringify({ ok: false, error: 'Purchase is currently processing' }), {
              status: 409,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
          }
        }
      }
      throw auditError;
    }

    const { error: txError } = await adminClient.from('google_play_transactions').upsert({
      user_id: userId,
      product_id: productId,
      purchase_token: purchaseToken,
      order_id: verification.orderId || clientOrderId || null,
      purchase_time: new Date().toISOString(),
      environment: 'Production',
      verified: true,
    }, { onConflict: 'purchase_token' });
    if (txError) {
      await adminClient.from('purchase_audit_log').delete().eq('id', audit.id);
      throw txError;
    }

    try {
      if (isSubscription) {
        const packageName = SUBSCRIPTIONS[productId];
        const { data: pkg, error: pkgError } = await adminClient
          .from('subscription_packages')
          .select('id')
          .eq('name', packageName)
          .eq('is_active', true)
          .maybeSingle();
          
        if (pkgError || !pkg) throw new Error(`Subscription package unavailable: ${packageName}`);

        const purchaseDate = verification.startTimeMillis
          ? new Date(Number(verification.startTimeMillis)).toISOString()
          : new Date().toISOString();
        const expiresDate = verification.expiryTimeMillis
          ? new Date(Number(verification.expiryTimeMillis)).toISOString()
          : null;

        // Invalidate old active subscriptions
        await adminClient
          .from('user_subscriptions')
          .update({ is_active: false, end_date: new Date().toISOString() })
          .eq('user_id', userId)
          .eq('is_active', true);

        // Insert new subscription or update if it exists
        const { error: subError } = await adminClient.from('user_subscriptions').upsert({
          user_id: userId,
          package_id: pkg.id,
          start_date: purchaseDate,
          end_date: expiresDate,
          is_active: expiresDate ? new Date(expiresDate) > new Date() : true,
          payment_status: 'paid',
          transaction_id: verification.orderId || clientOrderId || purchaseToken,
        }, { onConflict: 'user_id,package_id' });
        if (subError) throw subError;
        
      } else if (isToken) {
        const amount = TOKENS[productId];
        const { error: tokenError } = await adminClient.from('tokens').insert({
          user_id: userId,
          token_type: 'messages',
          amount,
          total_activations: amount,
          remaining_activations: amount,
          used_activations: 0,
          activation_type: 'purchase',
          source: 'google_play',
          notes: `Google Play IAP: ${productId}`,
        });
        if (tokenError) throw tokenError;
      } else if (isPromo) {
        // Event promos are not fully implemented in DB schema yet.
        // We report them as an unsupported path for now rather than inventing tables.
        throw new Error('Event promotions storage is not yet implemented.');
      }

      await adminClient
        .from('purchase_audit_log')
        .update({
          metadata: {
            status: 'granted',
            environment: 'Production',
            productId,
          },
        })
        .eq('id', audit.id);

      return new Response(JSON.stringify({ ok: true, environment: 'Production', productId, verified: true }), { 
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      });
      
    } catch (grantError) {
      // Allow a legitimate retry if the entitlement write itself failed
      await adminClient.from('google_play_transactions').delete().eq('purchase_token', purchaseToken);
      await adminClient.from('purchase_audit_log').delete().eq('id', audit.id);
      throw grantError;
    }
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : 'Server error';
    return new Response(JSON.stringify({ ok: false, error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
