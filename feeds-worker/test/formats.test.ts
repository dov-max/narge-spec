import { describe, it, expect, beforeAll } from "vitest";
import { call, addToken } from "./helpers";
import { FORMATS } from "../src/formats";

const TOK = "cdefghijklmnopqrstuvwxyz23";
beforeAll(async () => { await addToken(TOK, "formats-co"); });

const FIRST: Record<string, (s: string) => boolean> = {
  "narge.txt": (s) => s.startsWith("# Narge list") && /^[a-z0-9.-]+\.[a-z]+$/m.test(s),
  "narge.hosts": (s) => /^0\.0\.0\.0 [a-z0-9.-]+$/m.test(s),
  "narge-wildcard.txt": (s) => /^\*\.[a-z0-9.-]+$/m.test(s),
  "narge.rpz": (s) => s.startsWith("$TTL") && /CNAME \.$/m.test(s),
  "narge-adguard.txt": (s) => s.startsWith("!") && /^\|\|[a-z0-9.-]+\^$/m.test(s),
  "narge-plain-nocomments.txt": (s) => !/^[#!;]/m.test(s) && s.split("\n").filter(Boolean).length >= 200,
  "narge.csv": (s) => s.startsWith("domain\n"),
  "narge-controld.json": (s) => Array.isArray(JSON.parse(s).folder.rules),
  "version.json": (s) => { const v = JSON.parse(s); return v.count >= 200 && /^[0-9a-f]{64}$/.test(v.sha256); },
};

describe("format routes", () => {
  it("has exactly the 9 formats", () => {
    expect(Object.keys(FORMATS).sort()).toEqual(Object.keys(FIRST).sort());
  });

  for (const file of Object.keys(FIRST)) {
    it(`serves ${file} with token, public and /v1/<file> alias`, async () => {
      for (const p of [`/v1/${TOK}/${file}`, `/v1/public/${file}`, `/v1/${file}`]) {
        const r = await call(p);
        expect(r.status, p).toBe(200);
        expect(r.headers.get("content-type")).toBe(FORMATS[file]);
        expect(r.headers.get("cache-control")).toContain("max-age=3600");
        const body = await r.text();
        expect(FIRST[file](body), p).toBe(true);
      }
    });
  }

  it("supports HEAD and conditional GET (304)", async () => {
    const r1 = await call(`/v1/${TOK}/narge.txt`);
    const etag = r1.headers.get("etag");
    await r1.text();
    expect(etag).toBeTruthy();
    const h = await call(`/v1/${TOK}/narge.txt`, { method: "HEAD" });
    expect(h.status).toBe(200);
    const r2 = await call(`/v1/${TOK}/narge.txt`, { headers: { "if-none-match": etag! } });
    expect(r2.status).toBe(304);
  });
});
