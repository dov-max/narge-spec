import { sha256hex } from "./crypto";

export interface Org { org: string; status: "active" | "grace" | "revoked" }

// Tokens: 26 chars of RFC 4648 base32 lower-case (128 random bits), or "public".
export const TOKEN_RE = /^[a-z2-7]{26}$/;
const PUBLIC: Org = { org: "public", status: "active" };
const TTL_MS = 5 * 60 * 1000;
const cache = new Map<string, { v: Org | null; exp: number }>();

export async function lookupToken(kv: KVNamespace, token: string): Promise<Org | null> {
  if (token === "public") return PUBLIC;
  if (!TOKEN_RE.test(token)) return null;
  const h = await sha256hex(token);
  const now = Date.now();
  const c = cache.get(h);
  if (c && c.exp > now) return c.v;
  const v = await kv.get<Org>("t:" + h, "json");
  const org = v && typeof v.org === "string" && v.org !== "public" ? v : null;
  cache.set(h, { v: org, exp: now + TTL_MS });
  return org;
}

export function _clearTokenCache() { cache.clear(); }
