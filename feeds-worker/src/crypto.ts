const enc = new TextEncoder();

export function hex(buf: ArrayBuffer, bytes?: number): string {
  const a = new Uint8Array(buf, 0, bytes ?? buf.byteLength);
  let s = "";
  for (const b of a) s += b.toString(16).padStart(2, "0");
  return s;
}

export async function sha256hex(s: string): Promise<string> {
  return hex(await crypto.subtle.digest("SHA-256", enc.encode(s)));
}

async function hmacKey(raw: ArrayBuffer | Uint8Array): Promise<CryptoKey> {
  return crypto.subtle.importKey("raw", raw, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
}

// Daily key: K_day = HMAC(COUNTER_SECRET, "cutline-feeds/counter/v1/" + day).
// Derived per isolate and held only in memory; nothing derived from it is persisted.
let cached: { day: string; key: CryptoKey } | null = null;
export async function dayKey(secret: string, day: string): Promise<CryptoKey> {
  if (cached && cached.day === day) return cached.key;
  const base = await hmacKey(enc.encode(secret));
  const raw = await crypto.subtle.sign("HMAC", base, enc.encode("cutline-feeds/counter/v1/" + day));
  const key = await hmacKey(raw);
  cached = { day, key };
  return key;
}

// Fetcher id for de-dup within one day: first 8 bytes of HMAC(K_day, normalised address).
export async function fetcherId(secret: string, day: string, norm: string): Promise<string> {
  const k = await dayKey(secret, day);
  return hex(await crypto.subtle.sign("HMAC", k, enc.encode(norm)), 8);
}

export function utcDay(d = new Date()): string {
  return d.toISOString().slice(0, 10);
}
