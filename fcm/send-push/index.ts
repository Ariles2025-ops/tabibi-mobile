// send-push — envoi d'une push via FCM HTTP v1 (DEPLOYEE sur Supabase)
// Auth: exige l'en-tete Authorization: Bearer <SERVICE_ROLE_KEY> (le trigger l'envoie).
// Secrets requis (dashboard Supabase): FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';

const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

async function accessToken(): Promise<string> {
  const email = Deno.env.get('FIREBASE_CLIENT_EMAIL')!;
  const key = Deno.env.get('FIREBASE_PRIVATE_KEY')!.replace(/\\n/g, '\n');
  const pem = key.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const ck = await crypto.subtle.importKey(
    'pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const jwt = await create({ alg: 'RS256', typ: 'JWT' }, {
    iss: email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: getNumericDate(0), exp: getNumericDate(3600),
  }, ck);
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  return (await r.json()).access_token;
}

Deno.serve(async (req) => {
  const auth = req.headers.get('authorization') ?? '';
  if (!SERVICE_ROLE || auth !== `Bearer ${SERVICE_ROLE}`) return new Response('unauthorized', { status: 401 });
  try {
    const { user_id, title, body, data } = await req.json();
    if (!user_id || !title) return new Response('user_id & title requis', { status: 400 });
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, SERVICE_ROLE);
    const { data: toks } = await sb.from('device_tokens').select('token').eq('user_id', user_id);
    if (!toks?.length) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    const project = Deno.env.get('FIREBASE_PROJECT_ID')!;
    const at = await accessToken();
    let sent = 0;
    for (const { token } of toks) {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, {
        method: 'POST', headers: { authorization: `Bearer ${at}`, 'content-type': 'application/json' },
        body: JSON.stringify({ message: { token, notification: { title, body: body ?? '' }, data: data ?? {} } }),
      });
      if (res.ok) sent++;
    }
    return new Response(JSON.stringify({ sent }), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (e) { return new Response(String(e), { status: 500 }); }
});
