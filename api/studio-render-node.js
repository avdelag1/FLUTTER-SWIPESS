import webWorker from './studio-render.js';

function copyHeaders(nodeHeaders) {
  const headers = new Headers();
  for (const [key, value] of Object.entries(nodeHeaders ?? {})) {
    if (value == null) continue;
    if (Array.isArray(value)) {
      for (const item of value) headers.append(key, String(item));
    } else {
      headers.set(key, String(value));
    }
  }
  return headers;
}

async function readNodeBody(request) {
  if (request.body != null) {
    if (Buffer.isBuffer(request.body)) return request.body;
    if (typeof request.body === 'string') return Buffer.from(request.body);
    return Buffer.from(JSON.stringify(request.body));
  }

  const chunks = [];
  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks);
}

export default async function handler(request, response) {
  try {
    const method = String(request.method ?? 'GET').toUpperCase();
    const host = String(request.headers?.host ?? 'www.swipess.com');
    const forwardedProto = request.headers?.['x-forwarded-proto'];
    const protocol = Array.isArray(forwardedProto)
      ? String(forwardedProto[0] ?? 'https')
      : String(forwardedProto ?? 'https');
    const url = `${protocol}://${host}${request.url ?? '/api/studio-render-node'}`;
    const headers = copyHeaders(request.headers);

    const init = { method, headers };
    if (method !== 'GET' && method !== 'HEAD') {
      init.body = await readNodeBody(request);
    }

    const webResponse = await webWorker(new Request(url, init));
    response.statusCode = webResponse.status;
    webResponse.headers.forEach((value, key) => response.setHeader(key, value));
    const bytes = Buffer.from(await webResponse.arrayBuffer());
    response.end(bytes);
  } catch (error) {
    console.error('[studio-render-node]', error);
    response.statusCode = 500;
    response.setHeader('content-type', 'application/json; charset=utf-8');
    response.setHeader('cache-control', 'no-store');
    response.end(
      JSON.stringify({
        error: error instanceof Error ? error.message.slice(0, 1800) : String(error).slice(0, 1800),
      }),
    );
  }
}
