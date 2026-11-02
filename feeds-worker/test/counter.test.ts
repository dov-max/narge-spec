import { describe, it, expect, beforeAll, vi } from "vitest";
import { env } from "cloudflare:workers";
import { call, addToken } from "./helpers";
import { fetcherId, utcDay } from "../src/crypto";
import { normIp } from "../src/ip";

const TOK_A = "defghijklmnopqrstuvwxyz234";
const TOK_B = "efghijklmnopqrstuvwxyz2345";
const E = env as Env;
const stub = () => E.COUNTER.get(E.COUNTER.idFromName("counter-v1"));

// Documentation-range addresses only.
const v4 = (n: number) => `203.0.113.${n}`;
const IPS_9 = Array.from({ length: 9 }, (_, i) => v4(10 + i));
const IPS_10 = Array.from({ length: 10 }, (_, i) => `198.51.100.${10 + i}`);
const V6_SAME_64 = ["2001:db8:1:2::1", "2001:db8:1:2:aaaa::5", "2001:0db8:0001:0002:ffff:ffff:ffff:ffff"];

beforeAll(async () => {
  await addToken(TOK_A, "co-a");
  await addToken(TOK_B, "co-b");
});

describe("ip normalisation", () => {
  it("keeps IPv4, reduces IPv6 to /64, unmaps v4-mapped", () => {
    expect(normIp("192.0.2.7")).toBe("192.0.2.7");
    expect(new Set(V6_SAME_64.map(normIp)).size).toBe(1);
    expect(normIp("2001:db8:1:2::1")).toBe("2001:db8:1:2::/64");
    expect(normIp("::ffff:192.0.2.9")).toBe("192.0.2.9");
  });
});

describe("IP-free counter", () => {
  const today = utcDay();
  const all: string[] = [];

  it("counts, de-dups and applies the k=10 threshold", async () => {
    const logSpy = ["log", "info", "warn", "error", "debug"].map((m) => vi.spyOn(console, m as any));

    // ASN 64500: 9 distinct fetchers (below k). Each fetches twice and with two tokens.
    for (const ip of IPS_9) {
      for (const t of [TOK_A, TOK_B]) {
        expect((await call(`/v1/${t}/narge.txt`, { ip, asn: 64500, asOrg: "Small ISP" })).status).toBe(200);
      }
      await call(`/v1/${TOK_A}/narge.rpz`, { ip, asn: 64500, asOrg: "Small ISP" });
    }
    // ASN 64501: exactly 10 distinct fetchers (at k). Includes a 304.
    let etag = "";
    for (const ip of IPS_10) {
      const r = await call(`/v1/${TOK_A}/narge.txt`, { ip, asn: 64501, asOrg: "Big ISP" });
      etag = r.headers.get("etag") ?? etag; await r.text();
      await call(`/v1/${TOK_A}/narge.txt`, { ip, asn: 64501, asOrg: "Big ISP", headers: { "if-none-match": etag } });
    }
    // ASN 64502: three IPv6 addresses in one /64 -> 1 distinct.
    for (const ip of V6_SAME_64) await call(`/v1/public/narge.txt`, { ip, asn: 64502, asOrg: "V6 Net" });
    all.push(...IPS_9, ...IPS_10, ...V6_SAME_64);

    for (const s of logSpy) expect(s).not.toHaveBeenCalled();

    // Inspect live (pre-finalise) aggregate held by the counter.
    const snap = (await stub().snapshot()) as any;
    const agg = snap.storage["agg"] as any;
    expect(agg.day).toBe(today);
    const row = (k: string) => agg.rows[k];
    expect(row("*|64500").distinct).toBe(9);
    expect(row("*|64500").n200).toBe(27);
    expect(row("co-a|64500").distinct).toBe(9);
    expect(row("co-b|64500").distinct).toBe(9);
    expect(row("*|64501").distinct).toBe(10);
    expect(row("*|64501").n200).toBe(10);
    expect(row("*|64501").n304).toBe(10);
    expect(row("*|64502").distinct).toBe(1);

    // Finalise the day (as the 00:05 UTC cron / first hit of the next day would).
    await stub().ping("2999-12-31");
    const pub = JSON.parse((await E.STATS.get("pub:" + today))!);
    expect(pub.k).toBe(10);
    expect(pub.asns.map((r: any) => r.asn)).toEqual([64501]);
    expect(pub.asns[0]).toMatchObject({ asn: 64501, as_org: "Big ISP", distinct: 10, fetches: 20 });
    expect(pub.suppressed_asn_rows).toBe(2);
    expect(await E.STATS.get("pub:latest")).toBe(await E.STATS.get("pub:" + today));
    const priv = JSON.parse((await E.STATS.get("agg:" + today))!);
    expect(priv.rows["co-a|64501"].distinct).toBe(10);
  });

  it("stores no IP, no IPv6 prefix and no per-fetcher hash anywhere", async () => {
    expect(E.COUNTER_SECRET).toBe("test-only-not-a-real-secret-0123456789abcdef"); // needles below are real
    const needles: string[] = [];
    for (const ip of all) {
      needles.push(ip, normIp(ip));
      needles.push(await fetcherId("test-only-not-a-real-secret-0123456789abcdef", today, normIp(ip)));
    }
    needles.push("2001:db8", "203.0.113", "198.51.100");

    const dump: string[] = [];
    for (const ns of [E.STATS, E.TOKENS]) {
      const { keys } = await ns.list();
      for (const k of keys) dump.push(k.name, JSON.stringify(k.metadata ?? null), (await ns.get(k.name)) ?? "");
    }
    const snap = (await stub().snapshot()) as any;
    dump.push(JSON.stringify(snap.storage));
    const blob = dump.join("\n");
    for (const n of needles) expect(blob.includes(n), `found ${n}`).toBe(false);
    // After finalise, the counter object holds nothing persisted.
    expect(Object.keys(snap.storage)).toEqual([]);
  });

  it("serves the feed even with no address / no secret-derived id", async () => {
    expect((await call(`/v1/public/narge.txt`)).status).toBe(200);
  });

  it("publishes stats.json from the last finalised day", async () => {
    const r = await call(`/stats.json`);
    expect(r.status).toBe(200);
    const s = await r.json() as any;
    expect(s.day).toBe(today);
    expect(JSON.stringify(s)).not.toMatch(/co-a|co-b|203\.0\.113|198\.51\.100|2001:db8/);
  });
});
