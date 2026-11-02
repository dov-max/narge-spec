import { describe, it, expect, beforeAll } from "vitest";
import { call, addToken } from "./helpers";

const GOOD = "abcdefghijklmnopqrstuvwxyz"; // 26 base32 chars (test only)
const REVOKED = "zzzzzzzzzzzzzzzzzzzzzzzzzz";
const GRACE = "aaaaaaaaaaaaaaaaaaaaaaaaaa";
const UNKNOWN = "bbbbbbbbbbbbbbbbbbbbbbbbbb";

beforeAll(async () => {
  await addToken(GOOD, "acme");
  await addToken(REVOKED, "oldco", "revoked");
  await addToken(GRACE, "rotating", "grace");
});

describe("token handling", () => {
  it("accepts a known token", async () => {
    const r = await call(`/v1/${GOOD}/narge.txt`);
    expect(r.status).toBe(200);
  });

  it("rejects unknown, malformed and revoked tokens with the same 404", async () => {
    const paths = [
      `/v1/${UNKNOWN}/narge.txt`,
      `/v1/${REVOKED}/narge.txt`,
      `/v1/ABCDEFGHIJKLMNOPQRSTUVWXYZ/narge.txt`, // upper case
      `/v1/abc/narge.txt`,                         // too short
      `/v1/${GOOD}x/narge.txt`,                    // too long
      `/v1/abcdefghijklmnopqrstuvwxy1/narge.txt`,  // '1' not base32
    ];
    const bodies = new Set<string>();
    for (const p of paths) {
      const r = await call(p);
      expect(r.status, p).toBe(404);
      bodies.add(await r.text());
    }
    expect(bodies.size).toBe(1);
  });

  it("never treats a KV entry named 'public' as an org", async () => {
    const r = await call(`/v1/public/narge.txt`);
    expect(r.status).toBe(200);
  });

  it("rejects unknown files, traversal and other paths", async () => {
    for (const p of [`/v1/${GOOD}/secret.txt`, `/v1/${GOOD}/..%2fnarge.txt`, `/v1/${GOOD}/narge.txt/`, `/narge.txt`, `/`, `/v2/public/narge.txt`, `/v1/public/`]) {
      expect((await call(p)).status, p).toBe(404);
    }
  });

  it("dot-segments normalise to the public alias, never outside /v1", async () => {
    // WHATWG URL parsing turns /v1/<tok>/../narge.txt into /v1/narge.txt (the anonymous alias).
    expect((await call(`/v1/${GOOD}/../narge.txt`)).status).toBe(200);
    expect((await call(`/v1/../wrangler.toml`)).status).toBe(404);
    expect((await call(`/v1/${GOOD}/%2e%2e/narge.txt`)).status).toBe(200);
  });

  it("rejects non-GET/HEAD", async () => {
    expect((await call(`/v1/${GOOD}/narge.txt`, { method: "POST" })).status).toBe(405);
  });

  it("serves grace tokens with a Deprecation header", async () => {
    const r = await call(`/v1/${GRACE}/narge.txt`);
    expect(r.status).toBe(200);
    expect(r.headers.get("deprecation")).toBe("true");
  });
});

describe("KV failure", () => {
  it("fails open (serves the public list) if the token store throws", async () => {
    const { env } = await import("cloudflare:workers");
    const { _clearTokenCache } = await import("../src/tokens");
    _clearTokenCache();
    const kv = (env as Env).TOKENS;
    const orig = kv.get;
    (kv as any).get = () => { throw new Error("KV daily read limit"); };
    try {
      const r = await call(`/v1/cccccccccccccccccccccccccc/narge.txt`);
      expect(r.status).toBe(200);
    } finally { (kv as any).get = orig; }
  });
});
