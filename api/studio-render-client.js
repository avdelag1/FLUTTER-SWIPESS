import studioRenderHandler from './studio-render.js';

function cors(request) {
  const origin = request.headers.get('origin') || '*';
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
    'access-control-allow-credentials': 'true',
    'access-control-max-age': '600',
    'vary': 'Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
  };
}

export default async function handler(request) {
  const corsHeaders = cors(request);
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const response = await studioRenderHandler(request);
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
