import { FORMATS } from "./formats";
import { lookupToken, type Org } from "./tokens";
import { fetcherId, utcDay } from "./crypto";
import { normIp } from "./ip";

export { FetchCounter } from "./counter";

// Privacy rule for this file: never console.log / console.error anything, and never
// persist or return the connecting address. It is read once, normalised, HMAC'd, dropped.

const PATH_RE = /^\/v1\/(?:([a-z2-7]{26}|public)\/)?([a-z0-9.-]+)$/;
const NF_BODY = "not found\n";
const CACHE = "public, max-age=3600, stale-if-error=86400";

function notFound(): Response {
  return new Response(NF_BODY, { status: 404, headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" } });
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(req.url);
    if (req.method !== "GET" && req.method !== "HEAD") {
      return new Response("method not allowed\n", { status: 405, headers: { allow: "GET, HEAD" } });
    }
    if (url.pathname === "/stats.json") {
      const pub = await env.STATS.get("pub:latest");
      return new Response(pub ?? "{}", { headers: { "content-type": "application/json; charset=utf-8", "cache-control": "public, max-age=3600" } });
    }
    const m = url.pathname.match(PATH_RE);
    if (!m) return notFound();
    const token = m[1] ?? "public"; // /v1/<file> (URL printed in PR #66 headers) = anonymous
    const file = m[2];
    if (!Object.hasOwn(FORMATS, file)) return notFound();

    let org: Org | null;
    try {
      org = await lookupToken(env.TOKENS, token);
    } catch {
      // KV unavailable (e.g. free-plan daily read cap): fail open. The list is public anyway;
      // the fetch is counted as unattributed rather than breaking customers' firewalls.
      org = { org: "unattributed", status: "active" };
    }
    if (!org || org.status === "revoked") return notFound(); // same 404 for unknown/malformed/revoked

    if (env.RL) {
      const { success } = await env.RL.limit({ key: "org:" + org.org });
      if (!success) return new Response("slow down\n", { status: 429, headers: { "retry-after": "60" } });
    }

    const assetReq = new Request(new URL("/" + file, url.origin), {
      method: req.method,
      headers: pick(req.headers, ["if-none-match", "if-modified-since"]),
    });
    const res = await env.ASSETS.fetch(assetReq);
    if (res.status !== 200 && res.status !== 304) return notFound();

    if (env.COUNTER_SECRET) {
      const ip = req.headers.get("cf-connecting-ip") ?? "";
      const cf = (req as Request & { cf?: IncomingRequestCfProperties }).cf;
      const day = utcDay();
      const status = res.status;
      ctx.waitUntil(
        (async () => {
          const fid = ip ? await fetcherId(env.COUNTER_SECRET!, day, normIp(ip)) : "";
          const stub = env.COUNTER.get(env.COUNTER.idFromName("counter-v1"));
          await stub.hit({ day, org: org.org, asn: Number(cf?.asn ?? 0), asOrg: String(cf?.asOrganization ?? ""), fid, status });
        })().catch(() => {}), // counting never affects the response, and errors are not logged
      );
    }

    const out = new Response(res.body, res);
    out.headers.set("content-type", FORMATS[file]);
    out.headers.set("cache-control", CACHE);
    out.headers.set("x-content-type-options", "nosniff");
    if (org.status === "grace") out.headers.set("deprecation", "true");
    return out;
  },

  async scheduled(_ev: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    const stub = env.COUNTER.get(env.COUNTER.idFromName("counter-v1"));
    ctx.waitUntil(stub.ping(utcDay()).catch(() => {}));
  },
} satisfies ExportedHandler<Env>;

function pick(h: Headers, names: string[]): Headers {
  const o = new Headers();
  for (const n of names) { const v = h.get(n); if (v) o.set(n, v); }
  return o;
}
