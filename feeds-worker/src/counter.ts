import { DurableObject } from "cloudflare:workers";
import { utcDay } from "./crypto";

// IP-free fetch counter.
// - Receives only (day, org, asn, asOrg, fetcher id, status). Never an IP.
// - The fetcher-id de-dup sets live in memory only and are dropped at day end.
// - Persisted (DO SQLite storage and KV): counts only. No fetcher ids, no keys, no IPs.
// - If the object is evicted mid-day the sets are lost; "resets" is incremented and that
//   day's distinct counts become an upper bound.

export interface Row { org: string; asn: number; as_org: string; distinct: number; n200: number; n304: number }
export interface DayAgg { day: string; rows: Record<string, Row>; resets: number }
export interface Hit { day: string; org: string; asn: number; asOrg: string; fid: string; status: number }

export interface PublicStats {
  day: string;
  generated: string;
  k: number;
  total_fetches: number;
  asns: { asn: number; as_org: string; distinct: number; fetches: number }[];
  suppressed_asn_rows: number;
  counter_resets: number;
  note: string;
}

const FLUSH_MS = 5 * 60 * 1000;

export class FetchCounter extends DurableObject<Env> {
  private agg: DayAgg | null = null;
  private seen = new Map<string, Set<string>>(); // in memory only
  private dirty = false;
  private lastFlush = 0;
  private loaded: Promise<void>;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.loaded = ctx.blockConcurrencyWhile(async () => {
      const stored = await ctx.storage.get<DayAgg>("agg");
      if (stored) {
        // Memory was lost since the last flush: de-dup sets are gone.
        stored.resets += 1;
        this.agg = stored;
        this.dirty = true;
      }
    });
  }

  private async rollTo(day: string): Promise<void> {
    if (this.agg && this.agg.day >= day) return; // late hit from just before midnight: count in current day
    if (this.agg) await this.finalize(this.agg);
    {
      this.agg = { day, rows: {}, resets: 0 };
      this.seen.clear();
      this.dirty = true;
    }
  }

  private async finalize(agg: DayAgg): Promise<void> {
    const k = parseInt(this.env.K_MIN ?? "10", 10) || 10;
    const pub = publicStats(agg, k);
    await this.env.STATS.put("agg:" + agg.day, JSON.stringify(agg));
    await this.env.STATS.put("pub:" + agg.day, JSON.stringify(pub));
    await this.env.STATS.put("pub:latest", JSON.stringify(pub));
    this.seen.clear();
    await this.ctx.storage.deleteAll();
    this.agg = null;
  }

  private async flush(force = false): Promise<void> {
    if (!this.agg || !this.dirty) return;
    const now = Date.now();
    if (!force && now - this.lastFlush < FLUSH_MS) return;
    await this.ctx.storage.put("agg", this.agg); // counts only
    this.dirty = false;
    this.lastFlush = now;
  }

  async hit(h: Hit): Promise<void> {
    await this.loaded;
    await this.rollTo(h.day);
    const agg = this.agg!;
    const asn = Number.isFinite(h.asn) ? h.asn : 0;
    const asOrg = String(h.asOrg || "").slice(0, 120);
    const bump = (key: string, org: string) => {
      const row = (agg.rows[key] ??= { org, asn, as_org: asOrg, distinct: 0, n200: 0, n304: 0 });
      if (h.status === 304) row.n304++; else row.n200++;
      let set = this.seen.get(key);
      if (!set) this.seen.set(key, (set = new Set()));
      if (h.fid && !set.has(h.fid)) { set.add(h.fid); row.distinct++; }
    };
    bump(h.org + "|" + asn, h.org);   // per company per ASN (private)
    bump("*|" + asn, "*");            // per ASN across all companies (public, k-thresholded)
    this.dirty = true;
    await this.flush();
  }

  // Called by the minute cron: keeps the object resident and rolls the day over.
  async ping(day = utcDay()): Promise<void> {
    await this.loaded;
    if (this.agg && this.agg.day < day) await this.finalize(this.agg); // next hit starts the new day
    await this.flush();
  }

  // Test/ops helper: force a flush and return what is persisted (counts only).
  async snapshot(): Promise<{ storage: Record<string, unknown> }> {
    await this.loaded;
    await this.flush(true);
    return { storage: Object.fromEntries(await this.ctx.storage.list()) };
  }
}

export function publicStats(agg: DayAgg, k: number): PublicStats {
  const all = Object.values(agg.rows).filter((r) => r.org === "*");
  const shown = all.filter((r) => r.distinct >= k);
  return {
    day: agg.day,
    generated: new Date().toISOString(),
    k,
    total_fetches: all.reduce((s, r) => s + r.n200 + r.n304, 0),
    asns: shown
      .map((r) => ({ asn: r.asn, as_org: r.as_org, distinct: r.distinct, fetches: r.n200 + r.n304 }))
      .sort((a, b) => b.distinct - a.distinct || a.asn - b.asn),
    suppressed_asn_rows: all.length - shown.length,
    counter_resets: agg.resets,
    note: "Distinct = distinct fetching addresses per ASN per UTC day (IPv6 per /64). No addresses are stored. Rows below k are suppressed. If counter_resets > 0, distinct counts are an upper bound.",
  };
}
