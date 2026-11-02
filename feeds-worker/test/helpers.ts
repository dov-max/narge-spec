import { env } from "cloudflare:workers";
import { createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import worker from "../src/index";

export const BASE = "https://feeds.thecutline.org";

export async function call(path: string, opts: { method?: string; ip?: string; asn?: number; asOrg?: string; headers?: Record<string, string> } = {}) {
  const headers: Record<string, string> = { ...(opts.headers ?? {}) };
  if (opts.ip) headers["cf-connecting-ip"] = opts.ip;
  const req = new Request(BASE + path, {
    method: opts.method ?? "GET",
    headers,
    cf: { asn: opts.asn ?? 64496, asOrganization: opts.asOrg ?? "Test Net" },
  } as RequestInit);
  const ctx = createExecutionContext();
  const res = await worker.fetch(req as any, env as Env, ctx);
  await waitOnExecutionContext(ctx);
  return res;
}

export async function sha256hex(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function addToken(token: string, org: string, status = "active") {
  await (env as Env).TOKENS.put("t:" + (await sha256hex(token)), JSON.stringify({ org, status }));
}
